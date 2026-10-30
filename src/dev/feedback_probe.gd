## Brickworks, Send feedback… opens, attaches what the person chooses and
## sends it, and Brickworks, Beta hub is a tester's alone (beta374, FeedbackDialog,
## RecentLog, Shell.EARLY_COMMANDS).
##
##   tools/probe.sh feedback_probe
##   godot --path . --resolution 1400x900 --script src/dev/feedback_probe.gd
##   ... -- --shots=DIR    the dialog pictured there
##
## With a small model open and nobody signed in, it runs Send feedback as
## the app's menu (the mark's) does and reads the dialog:
##
##   it is up, with the picture of the window taken before it covered it,
##   shown small; Remove takes it off, Add a picture of the window puts it
##   back;
##   nothing but the picture is ticked; the version tick names the version
##   and the system, the model's names the model and its parts, the log's
##   counts the lines, which Show the log lines puts in front of them;
##   signed out, an email is asked for; Send with no kind, with no words and
##   with no email each says why and sends nothing;
##   chosen, typed and ticked, Send hands the stand-in (in place of the
##   deployment) exactly that: the kind, the words, the address, a JPEG the
##   width of the window at most 1600, the details, the model's LDraw text
##   and the log lines; the stand-in's answer is said, and Send becomes
##   Close;
##   the dialog, the log shown, fits the window, and in a short one what it
##   holds scrolls with Send still on the screen;
##   the picture removed and nothing ticked, none of it goes;
##   the app's menu has Send feedback and no Beta hub; the account's early
##   features given (Shell.set_early), it has Beta hub and it can run; taken
##   away, it has not and it cannot.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _shots: String = ""
var _sent: Array[Dictionary] = []

const MODEL := "0 FILE probe.ldr\n0 Probe\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		if _shell != null and _main.get("_bin") != null:
			break
	if _shell == null:
		print("  feedback probe: SKIPPED — the shell never came up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	var store: ModelStore = _main.get("_store")
	var opened: Dictionary = store.open_text(MODEL, "Probe")
	_check("a two-brick model is open", str(opened.get("error", "")).is_empty() and store.world.bricks().size() == 2)
	await _frames(20)
	# Something in the log to offer.
	print("feedback probe: a line for the log")

	await _menus()
	await _dialog()
	_finish()


func _menus() -> void:
	_check("the app's menu has Send feedback", "feedback" in _shell._shown(Shell.APP_MENU))
	_check("the app's menu has no Beta hub for an account that is not a tester",
		not "beta_hub" in _shell._shown(Shell.APP_MENU)
		and not _shell.can("beta_hub"))
	_shell.set_early(["beta_hub"] as Array[String])
	_check("a tester's app menu has Beta hub, and it can run", "beta_hub" in _shell._shown(Shell.APP_MENU)
		and _shell.can("beta_hub") and _shell.menu_id("beta_hub") >= 0)
	_shell.set_early([] as Array[String])
	_check("taken away, the app's menu has no Beta hub and it cannot run",
		not "beta_hub" in _shell._shown(Shell.APP_MENU)
		and not _shell.can("beta_hub"))


func _dialog() -> void:
	_check("Brickworks, Send feedback… can be run", _shell.run("feedback"))
	await _frames(12)
	var dialog: FeedbackDialog = _shell.feedback
	if not _check("the dialog is up", dialog != null and dialog.visible):
		return
	dialog.send = _stand_in
	var state: Dictionary = dialog.page_state()
	var window: int = root.get_texture().get_image().get_width()
	var size: Array = state["picture_size"]
	_check("the window's picture is attached, at most 1600 wide (%s of %d)" % [size, window],
		bool(state["picture"]) and size.size() == 2 and int(size[0]) == mini(window, 1600))
	_check("the dialog fits the window, Send on the screen", _fits(dialog) and dialog.get_ok_button().is_visible_in_tree())
	_check("signed out, an email is asked for", bool(state["email_asked"]))
	_check("the version tick names the version and the system (%s)" % state["version"],
		BuildInfo.version() in str(state["version"]) and OS.get_name() in str(state["version"]))
	_check("the model tick names it and its parts (%s)" % state["model"],
		"“Probe”, 2 parts" in str(state["model"]))
	_check("the log tick counts the lines (%s)" % state["log"], str(state["log"]).contains("last log lines ("))
	var controls: Dictionary = dialog.controls_by_name()
	for name: String in ["feedback_bug", "feedback_idea", "feedback_question", "feedback_words", "feedback_email",
			"feedback_picture_remove", "feedback_version", "feedback_model", "feedback_log", "feedback_show_log",
			"feedback_send", "feedback_cancel"]:
		_check("%s is named for a browser check" % name, controls.has(name))
	await _shot("01_open")

	# Nothing ticked but the picture.
	var body: Dictionary = dialog.body()
	_check("at first only the picture would go", body.has("picture") and not body.has("details")
		and not body.has("model") and not body.has("log"))
	# The log lines put in front of the person.
	(controls["feedback_show_log"] as Button).pressed.emit()
	await _frames(3)
	_check("Show the log lines shows them, the probe's line among them",
		bool(dialog.page_state()["log_shown"]) and dialog.body().is_empty() == false
		and _log_text(dialog).contains("feedback probe: a line for the log"))
	# Remove and add the picture.
	(controls["feedback_picture_remove"] as Button).pressed.emit()
	await _frames(3)
	_check("Remove takes the picture off", not bool(dialog.page_state()["picture"]) and not dialog.body().has("picture")
		and dialog.controls_by_name().has("feedback_picture_add"))
	(dialog.controls_by_name()["feedback_picture_add"] as Button).pressed.emit()
	await _frames(3)
	_check("Add a picture of the window puts it back", bool(dialog.page_state()["picture"]))

	# Refusals, each said, nothing sent.
	var send: Button = controls["feedback_send"]
	send.pressed.emit()
	await _frames(3)
	_check("no kind: said, nothing sent", _sent.is_empty() and "Choose what it is" in str(dialog.page_state()["status"]))
	(controls["feedback_bug"] as CheckBox).button_pressed = true
	send.pressed.emit()
	await _frames(3)
	_check("no words: said, nothing sent", _sent.is_empty() and "Say what happened" in str(dialog.page_state()["status"]))
	(controls["feedback_words"] as TextEdit).text = "The second brick floats when I undo."
	send.pressed.emit()
	await _frames(3)
	_check("no email: said, nothing sent", _sent.is_empty() and "email address" in str(dialog.page_state()["status"]))

	# Chosen, typed and ticked: sent as shown.
	(controls["feedback_email"] as LineEdit).text = "delivered+feedback-probe@resend.dev"
	for tick: String in ["feedback_version", "feedback_model", "feedback_log"]:
		(controls[tick] as CheckBox).button_pressed = true
	send.pressed.emit()
	for _n: int in 60:
		await process_frame
		if not _sent.is_empty() and bool(dialog.page_state()["sent"]):
			break
	await _frames(3)
	_check("the log shown and the answer said, it still fits the window", _fits(dialog))
	await _shot("02_sent")
	if not _check("Send hands the stand-in one report", _sent.size() == 1):
		return
	var went: Dictionary = _sent[0]
	_check("its kind, words, address and where it came from", went["kind"] == "bug"
		and went["words"] == "The second brick floats when I undo." and went["email"] == "delivered+feedback-probe@resend.dev"
		and went["source"] == "app" and went["token"] == "")
	var jpeg: PackedByteArray = Marshalls.base64_to_raw(str(went.get("picture", {}).get("data", "")))
	_check("the picture a JPEG of the window", went.get("picture", {}).get("type") == "image/jpeg"
		and jpeg.size() > 1000 and jpeg[0] == 0xff and jpeg[1] == 0xd8)
	var details: Dictionary = went.get("details", {})
	_check("the details: version, system, renderer, window (%s)" % [details],
		details.get("version") == BuildInfo.version() and not str(details.get("system", "")).is_empty()
		and not str(details.get("renderer", "")).is_empty() and str(details.get("window", "")).contains("x"))
	var model: Dictionary = went.get("model", {})
	_check("the model as its LDraw text", model.get("name") == "Probe" and str(model.get("text", "")).begins_with("0 ")
		and str(model.get("text", "")).count("3001.dat") == 2)
	_check("the log lines", str(went.get("log", "")).contains("feedback probe: a line for the log"))
	_check("the answer said, and Send is Close", str(dialog.page_state()["status"]) == "Thank you. Stood in."
		and send.text == "Close" and not dialog.controls_by_name().has("feedback_cancel"))
	send.pressed.emit()
	await _frames(3)
	_check("Close puts it away", not dialog.visible)

	# Again, with nothing but the words: nothing else goes.
	_check("Send feedback opens again", _shell.run("feedback"))
	await _frames(12)
	dialog.send = _stand_in
	controls = dialog.controls_by_name()
	_check("opened again, it starts afresh", (controls["feedback_words"] as TextEdit).text.is_empty()
		and not (controls["feedback_model"] as CheckBox).button_pressed)
	# A short window: what it holds scrolls, Send stays on the screen.
	var was: Vector2i = root.size
	root.size = Vector2i(1100, 560)
	await _frames(4)
	(controls["feedback_show_log"] as Button).pressed.emit()
	await _frames(6)
	_check("in a short window, the log shown, it fits and Send is on the screen", _fits(dialog)
		and dialog.get_ok_button().is_visible_in_tree())
	await _shot("03_short")
	(controls["feedback_show_log"] as Button).pressed.emit()
	root.size = was
	await _frames(6)
	(controls["feedback_question"] as CheckBox).button_pressed = true
	(controls["feedback_words"] as TextEdit).text = "Can I print the booklet?"
	(controls["feedback_email"] as LineEdit).text = "delivered+feedback-probe@resend.dev"
	(controls["feedback_picture_remove"] as Button).pressed.emit()
	await _frames(2)
	(controls["feedback_send"] as Button).pressed.emit()
	for _n: int in 60:
		await process_frame
		if _sent.size() == 2:
			break
	_check("with nothing ticked and the picture removed, only the words go", _sent.size() == 2
		and not _sent[1].has("picture") and not _sent[1].has("model") and not _sent[1].has("log")
		and not _sent[1].has("details") and _sent[1]["kind"] == "question")
	dialog.hide()


## Its title bar and its foot inside the window, in the window's own
## (content-scaled) units, as an embedded dialog is placed.
func _fits(dialog: FeedbackDialog) -> bool:
	var title: int = dialog.get_theme_constant("title_height")
	return root.get_visible_rect().grow(0.5).encloses(Rect2(dialog.position - Vector2i(0, title),
		dialog.size + Vector2i(0, title)))


func _log_text(dialog: FeedbackDialog) -> String:
	for child: Node in dialog.find_children("*", "TextEdit", true, false):
		if not (child as TextEdit).editable:
			return (child as TextEdit).text
	return ""


## In place of the deployment: kept, and answered as it would be.
func _stand_in(asked: Dictionary, token: String) -> Dictionary:
	await process_frame
	var kept: Dictionary = asked.duplicate(true)
	kept["token"] = token
	_sent.append(kept)
	return {"code": 200, "body": {"id": _sent.size(), "beta": false, "said": "Thank you. Stood in."}}


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	for _n: int in 4:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("feedback probe: %s" % ("all ok" if _failures == 0 else "%d failed" % _failures))
	quit(0 if _failures == 0 else 1)
