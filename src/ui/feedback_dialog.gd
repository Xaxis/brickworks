## Help, Send feedback…: a bug, an idea or a question, sent to the people
## who make Brickworks (POST /api/plans?op=feedback, api/_feedback.js), on
## the desktop and the web alike (beta374, 2026-10-30).
##
## A few words, and what the person chooses to send with it, each shown
## before it goes and each taken off again:
##
##   the picture   of the window as it was when Send feedback was chosen
##                 (taken before this dialog covered it), shown small, with
##                 Remove and Add it back
##   the version   ticked: the app's version, the system, the renderer and
##                 the window's size, said in words beside the tick
##   the model     ticked: the model open, as its LDraw file, named with its
##                 part count
##   the log       ticked: the app's last log lines ([RecentLog]), which
##                 Show the log lines puts in front of them first
##
## Nothing but the picture is ticked at first: what goes is chosen. Signed
## in, the account sends it and their reports are on their settings page;
## signed out, an address to answer at is asked for. A beta tester's report
## is marked beta by the server.
class_name FeedbackDialog
extends AcceptDialog

const KINDS: Array[String] = ["bug", "idea", "question"]
const KIND_WORDS: Array[String] = ["Something is wrong", "An idea", "A question"]
## The picture is sent at most this wide, as a JPEG.
const WIDEST := 1600
const MOST_WORDS := 4000
const LOG_LINES := 200
const WIDE := 460

var account: Account
var store: ModelStore
var world: BrickWorld
## For counting the model's parts as the status bar does (Inventory.pieces_in).
var library: PartLibrary
var recent: RecentLog
## How a report goes: (body: Dictionary, token: String) -> {code, body}.
## The deployment's API; a probe stands in for it.
var send: Callable = _post

var _kinds: Array[CheckBox] = []
var _words: TextEdit
var _email: LineEdit
var _email_row: VBoxContainer
var _thumb: TextureRect
var _picture_row: HBoxContainer
var _picture_words: Label
var _remove: Button
var _add: Button
var _version: CheckBox
var _model: CheckBox
var _log: CheckBox
var _show_log: Button
var _log_text: TextEdit
var _status: Label
var _cancel: Button
var _scroll: ScrollContainer
var _column: VBoxContainer

## The window as it was when the dialog was asked for, and whether it goes.
var _picture: Image
var _picture_on: bool = false
## The last answer, for a probe and the page: {code, body}.
var last_answer: Dictionary = {}
var _sending: bool = false


func _ready() -> void:
	title = "Send feedback"
	ok_button_text = "Send"
	dialog_hide_on_ok = false
	_cancel = add_cancel_button("Cancel")
	confirmed.connect(_on_send)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(WIDE, 0)
	_scroll.add_child(column)
	var said := Label.new()
	said.text = "Tell us what is wrong, what you would like, or ask us anything. We read every one ourselves."
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.custom_minimum_size = Vector2(WIDE, 0)
	column.add_child(said)

	var kinds := HFlowContainer.new()
	kinds.add_theme_constant_override("h_separation", 14)
	var group := ButtonGroup.new()
	for n: int in KINDS.size():
		var kind := CheckBox.new()
		kind.text = KIND_WORDS[n]
		kind.button_group = group
		kind.name = "kind_" + KINDS[n]
		kinds.add_child(kind)
		_kinds.append(kind)
	column.add_child(kinds)

	column.add_child(_label("What happened, or what would you like?"))
	_words = TextEdit.new()
	_words.custom_minimum_size = Vector2(WIDE, 110)
	_words.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_words.accessibility_name = "What happened, or what would you like?"
	column.add_child(_words)

	_email_row = VBoxContainer.new()
	_email_row.add_child(_label("Your email, so we can answer"))
	_email = LineEdit.new()
	_email.placeholder_text = "you@example.com"
	_email.accessibility_name = "Your email, so we can answer"
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email_row.add_child(_email)
	column.add_child(_email_row)

	column.add_child(_label("Send with it"))
	_picture_row = HBoxContainer.new()
	_picture_row.add_theme_constant_override("separation", 10)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(120, 75)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture_row.add_child(_thumb)
	var picture_side := VBoxContainer.new()
	picture_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picture_words = Label.new()
	_picture_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	picture_side.add_child(_picture_words)
	_remove = Button.new()
	_remove.text = "Remove the picture"
	_remove.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_remove.pressed.connect(func() -> void: _picture_shown(false))
	picture_side.add_child(_remove)
	_add = Button.new()
	_add.text = "Add a picture of the window"
	_add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add.pressed.connect(func() -> void: _picture_shown(true))
	picture_side.add_child(_add)
	_picture_row.add_child(picture_side)
	column.add_child(_picture_row)

	_version = _tick(column)
	_model = _tick(column)
	_log = _tick(column)
	_show_log = Button.new()
	_show_log.text = "Show the log lines"
	_show_log.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_show_log.pressed.connect(func() -> void:
		_log_text.visible = not _log_text.visible
		_show_log.text = "Hide the log lines" if _log_text.visible else "Show the log lines"
		_fit.call_deferred())
	column.add_child(_show_log)
	_log_text = TextEdit.new()
	_log_text.editable = false
	_log_text.visible = false
	_log_text.custom_minimum_size = Vector2(WIDE, 140)
	_log_text.accessibility_name = "The log lines that would be sent"
	column.add_child(_log_text)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(WIDE, 0)
	column.add_child(_status)


func _label(words: String) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(1, 1, 1, 0.8)
	return label


func _tick(column: Control) -> CheckBox:
	var tick := CheckBox.new()
	tick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tick.custom_minimum_size = Vector2(WIDE, 0)
	column.add_child(tick)
	return tick


## Open it, with [param window] the picture of the window taken before it
## covered it (null: none to offer). [param kind]: one of [constant KINDS]
## chosen at first, or none.
func open(window: Image, kind: String = "") -> void:
	_sending = false
	last_answer = {}
	get_ok_button().text = "Send"
	get_ok_button().disabled = false
	_cancel.visible = true
	_words.text = ""
	_status.text = ""
	for n: int in KINDS.size():
		_kinds[n].button_pressed = KINDS[n] == kind
	var signed_in: bool = account != null and account.signed_in()
	_email_row.visible = not signed_in
	_picture = _scaled(window) if window != null else null
	_picture_shown(_picture != null)
	_version.button_pressed = false
	_version.text = "The app's version and your system: %s" % _about_here()
	var parts: int = 0
	if world != null:
		parts = Inventory.pieces_in(world, library, store.scenery if store != null else {}) if library != null \
			else world.bricks().size()
	_model.button_pressed = false
	_model.disabled = parts == 0
	_model.text = ("The model you have open, as a file: “%s”, %d %s" % [_model_name(), parts,
		"part" if parts == 1 else "parts"]) if parts > 0 else "The model you have open, as a file (nothing is open)"
	var lines: PackedStringArray = recent.last(LOG_LINES) if recent != null else PackedStringArray()
	_log.button_pressed = false
	_log.disabled = lines.is_empty()
	_log.text = ("The app's last log lines (%d), which say what it was doing" % lines.size()) if not lines.is_empty() \
		else "The app's last log lines (there are none yet)"
	_log_text.text = "\n".join(lines)
	_log_text.visible = false
	_show_log.text = "Show the log lines"
	_show_log.visible = not lines.is_empty()
	popup_centered(Vector2i(WIDE + 40, 0))
	_fit.call_deferred()
	_words.grab_focus.call_deferred()


## As tall as what it holds, once that is laid out at its width (wrapped
## words measure tall before they know their width, and a window never
## shrinks by itself), and no taller than the window it is in: past that,
## what it holds scrolls and Send stays on the screen.
func _fit() -> void:
	await get_tree().process_frame
	if not visible:
		return
	const MARGIN := 24.0
	var room: float = get_tree().root.get_visible_rect().size.y
	var around: float = get_theme_constant("title_height") + get_ok_button().get_combined_minimum_size().y \
		+ get_theme_constant("buttons_separation") + MARGIN * 3.0
	_scroll.custom_minimum_size = Vector2(WIDE, minf(_column.get_combined_minimum_size().y,
		maxf(160.0, room - around)))
	reset_size()
	move_to_center()


func _scaled(window: Image) -> Image:
	var image: Image = window.duplicate()
	if image.get_width() > WIDEST:
		image.resize(WIDEST, int(round(float(image.get_height()) * WIDEST / image.get_width())),
			Image.INTERPOLATE_BILINEAR)
	image.convert(Image.FORMAT_RGB8)
	return image


func _picture_shown(on: bool) -> void:
	_picture_on = on and _picture != null
	_thumb.texture = ImageTexture.create_from_image(_picture) if _picture_on else null
	_thumb.visible = _picture_on
	_remove.visible = _picture_on
	_add.visible = not _picture_on and _picture != null
	_picture_row.visible = _picture != null
	_picture_words.text = ("A picture of the window as it was, %d × %d" % [_picture.get_width(),
		_picture.get_height()]) if _picture_on else "No picture."


func _model_name() -> String:
	var named: String = store.title if store != null else ""
	return "Untitled" if named.is_empty() or named == ModelStore.UNTITLED else named


## The app's version, the system, the renderer and the window's size, in words.
func _about_here() -> String:
	var size: Vector2i = get_tree().root.size
	return "Brickworks %s, %s, %s, %d × %d" % [BuildInfo.version(), _system(),
		RenderingServer.get_current_rendering_method(), size.x, size.y]


func _system() -> String:
	if OS.has_feature("web"):
		return "web (%s)" % OS.get_name()
	var version: String = OS.get_version()
	return OS.get_name() + ((" " + version) if not version.is_empty() else "")


## What would be sent now, as the server reads it.
func body() -> Dictionary:
	var kind: String = ""
	for n: int in KINDS.size():
		if _kinds[n].button_pressed:
			kind = KINDS[n]
	var out: Dictionary = {"kind": kind, "words": _words.text.strip_edges(), "source": "app",
		"page": "web" if OS.has_feature("web") else "desktop"}
	if _email_row.visible:
		out["email"] = _email.text.strip_edges()
	if _version.button_pressed:
		var size: Vector2i = get_tree().root.size
		out["details"] = {"version": BuildInfo.version(), "system": _system(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(), "window": "%dx%d" % [size.x, size.y]}
	if _picture_on and _picture != null:
		out["picture"] = {"type": "image/jpeg",
			"data": Marshalls.raw_to_base64(_picture.save_jpg_to_buffer(0.85))}
	if _model.button_pressed and not _model.disabled and store != null:
		out["model"] = {"name": _model_name(), "text": store.to_text(_model_name())}
	if _log.button_pressed and not _log.disabled:
		out["log"] = _log_text.text
	return out


func _on_send() -> void:
	if _sending:
		return
	if last_answer.get("code", 0) == 200:
		hide()
		return
	var asked: Dictionary = body()
	if str(asked["kind"]).is_empty():
		_status.text = "Choose what it is: something wrong, an idea or a question."
		return
	if str(asked["words"]).length() < 3:
		_status.text = "Say what happened, or what you would like."
		_words.grab_focus()
		return
	if str(asked["words"]).length() > MOST_WORDS:
		_status.text = "At most %d characters; that is %d." % [MOST_WORDS, str(asked["words"]).length()]
		return
	if _email_row.visible and not "@" in str(asked.get("email", "")):
		_status.text = "Give an email address, so we can answer you."
		_email.grab_focus()
		return
	_sending = true
	get_ok_button().disabled = true
	_status.text = "Sending…"
	var token: String = ""
	if account != null and account.signed_in():
		token = await account.access_token()
	var answer: Dictionary = await send.call(asked, token)
	_sending = false
	get_ok_button().disabled = false
	last_answer = answer
	var said: Variant = answer.get("body")
	var words: String = str((said as Dictionary).get("said", (said as Dictionary).get("error", ""))) \
		if said is Dictionary else ""
	if int(answer.get("code", 0)) != 200:
		_status.text = words if not words.is_empty() else "That did not go just now. Try again in a minute."
		return
	_status.text = words if not words.is_empty() else "Thank you."
	get_ok_button().text = "Close"
	_cancel.visible = false
	_fit.call_deferred()


## The deployment's API: the report, as JSON, with the sign-in when there is one.
func _post(asked: Dictionary, token: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 60.0
	add_child(http)
	var headers := PackedStringArray(["content-type: application/json"])
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	if http.request(Deployment.api_base() + "/api/plans?op=feedback", headers, HTTPClient.METHOD_POST,
			JSON.stringify(asked)) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}


## What a browser check presses and types into.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"feedback_words": _words, "feedback_send": get_ok_button(),
		"feedback_version": _version, "feedback_model": _model, "feedback_log": _log}
	for n: int in KINDS.size():
		out["feedback_" + KINDS[n]] = _kinds[n]
	if _email_row.visible:
		out["feedback_email"] = _email
	if _cancel.visible:
		out["feedback_cancel"] = _cancel
	if _remove.visible:
		out["feedback_picture_remove"] = _remove
	if _add.visible:
		out["feedback_picture_add"] = _add
	if _show_log.visible:
		out["feedback_show_log"] = _show_log
	return out


## What it shows and what would go, for a probe and the page.
func page_state() -> Dictionary:
	return {"open": visible, "email_asked": _email_row.visible if _email_row != null else false,
		"picture": _picture_on, "picture_size": [_picture.get_width(), _picture.get_height()] if _picture != null else [],
		"version": _version.text if _version != null else "", "model": _model.text if _model != null else "",
		"log": _log.text if _log != null else "", "log_shown": _log_text.visible if _log_text != null else false,
		"status": _status.text if _status != null else "", "sent": int(last_answer.get("code", 0)) == 200,
		"answer": last_answer.get("body") if last_answer.get("body") is Dictionary else {}}
