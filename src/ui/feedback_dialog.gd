## Brickworks, Send feedback…: a bug, an idea or a question, sent to the
## people who make Brickworks (POST /api/plans?op=feedback, api/_feedback.js),
## on the desktop and the web alike (beta374, 2026-10-30). And Report a bug…
## (bugreport, 2026-11-09), the same dialog made for a bug: one press from
## the top bar, Help, its key, or Report this on an error notice, while the
## beta is open.
##
## A few words, and what the person chooses to send with it, each shown
## before it goes and each taken off again:
##
##   the picture   of the window as it was when it was asked for (taken
##                 before this dialog covered it). Send feedback shows it
##                 small, with Remove and Add it back; a report shows it
##                 large, to mark the spot on (PictureMarks: drag a box),
##                 with Leave the picture out
##   the version   the app's version, the system, the renderer and the
##                 window's size, said in words beside the tick
##   the model     the model open, as its LDraw file, named with its part
##                 count
##   the log       the app's last log lines ([RecentLog]), which Show the
##                 log lines puts in front of them first; from an error
##                 notice, the lines up to that error
##
## Send feedback ticks nothing but the picture: what goes is chosen. A
## report ticks the version, as VS Code's Report Issue ticks its system
## information, and the log when it came from an error notice, whose lines
## are what is reported; never the model, which is the person's work. It
## says plainly, in a line of its own, everything that will go, before it
## goes. Signed in, the account sends it and their reports are on their
## settings page (Your reports); signed out, Send feedback asks for an
## address to answer at, and a report asks them to sign in. A beta tester's
## report is marked beta by the server.
##
## After a report goes: its number, and where to follow it (Your reports,
## with where it stands and our answers), as Linear's and GitHub's say
## where a new issue is.
class_name FeedbackDialog
extends AcceptDialog

const KINDS: Array[String] = ["bug", "idea", "question"]
const KIND_WORDS: Array[String] = ["Something is wrong", "An idea", "A question"]
## A report's title for each kind, chosen in it.
const REPORT_TITLES: Array[String] = ["Report a bug", "Share an idea", "Ask a question"]
## And what it asks first.
const REPORT_ASKS: Array[String] = ["What happened?", "What would you like?", "What would you like to ask?"]
## The picture is sent at most this wide, as a JPEG.
const WIDEST := 1600
const MOST_WORDS := 4000
## What was expected: the server keeps it with the words, after them, in
## at most MOST_WORDS together (api/_feedback.js).
const MOST_EXPECTED := 2000
const LOG_LINES := 200
const WIDE := 460
## A report's two halves side by side, the words and the picture, where the
## window has room for them; one above the other in a narrower one.
const REPORT_LEFT := 360
const REPORT_RIGHT := 480
const REPORT_GAP := 24
## Where Your reports is, on the site (web/settings.js).
const REPORTS_PATH := "/settings#feedback"

var account: Account
var store: ModelStore
var world: BrickWorld
## For counting the model's parts as the status bar does (Inventory.pieces_in).
var library: PartLibrary
var recent: RecentLog
## How a report goes: (body: Dictionary, token: String) -> {code, body}.
## The deployment's API; a probe stands in for it.
var send: Callable = _post

## Whether this is Report a bug… ([method open_report]), not Send feedback….
var reporting: bool = false
## Where a report was asked for: "bar", "menu", "key" or "notice"; and the
## error a notice said, sent in its details.
var from: String = ""
var _error: String = ""
## The lines an error notice's Report this carries: the log up to its error.
var _carried: PackedStringArray = []

var _kinds: Array[CheckBox] = []
var _said: Label
var _box: BoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _words_label: Label
var _words: TextEdit
var _expected_row: VBoxContainer
var _expected: TextEdit
var _email: LineEdit
var _email_row: VBoxContainer
var _thumb: TextureRect
var _picture_row: HBoxContainer
var _picture_words: Label
var _remove: Button
var _add: Button
var _marker: PictureMarks
var _marks_row: HFlowContainer
var _marks_words: Label
var _clear: Button
var _leave: Button
var _version: CheckBox
var _model: CheckBox
var _log: CheckBox
var _show_log: Button
var _log_text: TextEdit
var _sends_row: VBoxContainer
var _sends: Label
var _status: Label
var _cancel: Button
var _reports: Button
var _scroll: ScrollContainer
var _column: VBoxContainer
## How wide what it holds is laid out, for the mode and the window.
var _wide: float = WIDE

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
	_reports = add_button("Your reports", false, "reports")
	_reports.visible = false
	custom_action.connect(func(action: StringName) -> void:
		if action == &"reports":
			Outside.open_link(reports_link())
			hide())
	confirmed.connect(_on_send)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(WIDE, 0)
	_scroll.add_child(column)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.custom_minimum_size = Vector2(WIDE, 0)
	column.add_child(_said)

	# The words on the left and what goes with them on the right, in a
	# report on a wide window; one above the other otherwise.
	_box = BoxContainer.new()
	_box.vertical = true
	_box.add_theme_constant_override("separation", REPORT_GAP)
	column.add_child(_box)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 8)
	_box.add_child(_left)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_box.add_child(_right)

	var kinds := HFlowContainer.new()
	kinds.add_theme_constant_override("h_separation", 14)
	var group := ButtonGroup.new()
	for n: int in KINDS.size():
		var kind := CheckBox.new()
		kind.text = KIND_WORDS[n]
		kind.button_group = group
		kind.name = "kind_" + KINDS[n]
		kind.toggled.connect(func(_on: bool) -> void: _kind_chosen())
		kinds.add_child(kind)
		_kinds.append(kind)
	_left.add_child(kinds)

	_words_label = _label("What happened, or what would you like?")
	_left.add_child(_words_label)
	_words = TextEdit.new()
	_words.custom_minimum_size = Vector2(WIDE, 110)
	_words.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_words.accessibility_name = "What happened, or what would you like?"
	_left.add_child(_words)

	_expected_row = VBoxContainer.new()
	_expected_row.add_child(_label("What did you expect to happen? (optional)"))
	_expected = TextEdit.new()
	_expected.custom_minimum_size = Vector2(WIDE, 64)
	_expected.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_expected.accessibility_name = "What did you expect to happen? (optional)"
	_expected_row.add_child(_expected)
	_expected_row.visible = false
	_left.add_child(_expected_row)

	_email_row = VBoxContainer.new()
	_email_row.add_child(_label("Your email, so we can answer"))
	_email = LineEdit.new()
	_email.placeholder_text = "you@example.com"
	_email.accessibility_name = "Your email, so we can answer"
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email_row.add_child(_email)
	_left.add_child(_email_row)

	# What a report sends, all of it, in one line before it goes.
	_sends_row = VBoxContainer.new()
	_sends_row.add_child(_label("What will be sent"))
	_sends = Label.new()
	_sends.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sends.custom_minimum_size = Vector2(WIDE, 0)
	_sends.add_theme_font_size_override("font_size", 13)
	_sends_row.add_child(_sends)
	_sends_row.visible = false
	_left.add_child(_sends_row)

	_right.add_child(_label("Send with it"))
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
	_right.add_child(_picture_row)

	# A report's picture, large, to mark the spot on.
	_marker = PictureMarks.new()
	_marker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_marker.visible = false
	_marker.changed.connect(_marks_changed)
	_right.add_child(_marker)
	_marks_row = HFlowContainer.new()
	_marks_row.add_theme_constant_override("h_separation", 10)
	_marks_row.visible = false
	_marks_words = Label.new()
	_marks_words.add_theme_font_size_override("font_size", 13)
	_marks_words.modulate = Color(1, 1, 1, 0.8)
	_marks_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_marks_row.add_child(_marks_words)
	_clear = Button.new()
	_clear.text = "Clear the marks"
	_clear.pressed.connect(func() -> void: _marker.clear())
	_marks_row.add_child(_clear)
	_leave = Button.new()
	_leave.pressed.connect(func() -> void: _picture_shown(not _picture_on))
	_marks_row.add_child(_leave)
	_right.add_child(_marks_row)

	_version = _tick(_right)
	_model = _tick(_right)
	_log = _tick(_right)
	_show_log = Button.new()
	_show_log.text = "Show the log lines"
	_show_log.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_show_log.pressed.connect(func() -> void:
		_log_text.visible = not _log_text.visible
		_show_log.text = "Hide the log lines" if _log_text.visible else "Show the log lines"
		_fit.call_deferred())
	_right.add_child(_show_log)
	_log_text = TextEdit.new()
	_log_text.editable = false
	_log_text.visible = false
	_log_text.custom_minimum_size = Vector2(WIDE, 140)
	_log_text.accessibility_name = "The log lines that would be sent"
	_right.add_child(_log_text)
	_words.text_changed.connect(_say_sends)
	_expected.text_changed.connect(_say_sends)

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
	tick.toggled.connect(func(_on: bool) -> void: _say_sends())
	column.add_child(tick)
	return tick


## Send feedback…: open it, with [param window] the picture of the window
## taken before it covered it (null: none to offer). [param kind]: one of
## [constant KINDS] chosen at first, or none.
func open(window: Image, kind: String = "") -> void:
	reporting = false
	from = ""
	_error = ""
	_carried = PackedStringArray()
	_start(window, kind)
	title = "Send feedback"
	_said.text = "Tell us what is wrong, what you would like, or ask us anything. We read every one ourselves."
	get_ok_button().text = "Send"
	_show()


## Report a bug…: open it over the model, [param window] the picture of it
## taken before the dialog covered it, asked for from [param where] ("bar",
## "menu", "key" or "notice"). From an error notice, [param error] is what
## it said and [param lines] the log up to it, which go ticked.
func open_report(window: Image, where: String, lines: PackedStringArray = PackedStringArray(),
		error: String = "") -> void:
	reporting = true
	from = where
	_error = error
	_carried = lines
	_start(window, "bug")
	_said.text = "Tell us what went wrong. We read every report ourselves."
	get_ok_button().text = "Send report"
	_version.button_pressed = true
	_log.button_pressed = not lines.is_empty() and not _log.disabled
	if not _signed_in():
		_status.text = "Sign in to send a report: Account, at the top right."
	_show()


func _start(window: Image, kind: String) -> void:
	_sending = false
	last_answer = {}
	get_ok_button().disabled = false
	_cancel.visible = true
	_reports.visible = false
	_box.visible = true
	_words.text = ""
	_expected.text = ""
	_status.text = ""
	for n: int in KINDS.size():
		_kinds[n].set_pressed_no_signal(KINDS[n] == kind)
	_email_row.visible = not reporting and not _signed_in()
	_picture = _scaled(window) if window != null else null
	_marker.show_picture(_picture if reporting else null)
	_picture_shown(_picture != null)
	_version.button_pressed = false
	_version.text = "The app's version and your system: %s" % _about_here()
	var parts: int = _parts()
	_model.button_pressed = false
	_model.disabled = parts == 0
	_model.text = ("The model you have open, as a file: “%s”, %d %s" % [_model_name(), parts,
		"part" if parts == 1 else "parts"]) if parts > 0 else "The model you have open, as a file (nothing is open)"
	var lines: PackedStringArray = _carried if not _carried.is_empty() \
		else (recent.last(LOG_LINES) if recent != null else PackedStringArray())
	_log.button_pressed = false
	_log.disabled = lines.is_empty()
	_log.text = (("The app's log lines up to the error (%d), which say what it was doing" if not _carried.is_empty()
		else "The app's last log lines (%d), which say what it was doing") % lines.size()) if not lines.is_empty() \
		else "The app's last log lines (there are none yet)"
	_log_text.text = "\n".join(lines)
	_log_text.visible = false
	_show_log.text = "Show the log lines"
	_show_log.visible = not lines.is_empty()
	_kind_chosen()


func _show() -> void:
	_lay_out()
	_say_sends()
	popup_centered(Vector2i(int(_wide) + 40, 0))
	_fit.call_deferred()
	_words.grab_focus.call_deferred()


func _signed_in() -> bool:
	return account != null and account.signed_in()


func _parts() -> int:
	if world == null:
		return 0
	return Inventory.pieces_in(world, library, store.scenery if store != null else {}) if library != null \
		else world.bricks().size()


## The kind chosen: a report asks for it in its own words, and for what was
## expected only of a bug.
func _kind_chosen() -> void:
	var at: int = _kind_at()
	if reporting:
		title = REPORT_TITLES[maxi(at, 0)]
		_words_label.text = REPORT_ASKS[maxi(at, 0)]
		_words.accessibility_name = REPORT_ASKS[maxi(at, 0)]
		_expected_row.visible = at <= 0
	else:
		_words_label.text = "What happened, or what would you like?"
		_words.accessibility_name = "What happened, or what would you like?"
		_expected_row.visible = false
	if visible:
		_fit.call_deferred()


func _kind_at() -> int:
	for n: int in KINDS.size():
		if _kinds[n].button_pressed:
			return n
	return -1


## The widths for the mode and the window: a report on a wide window side by
## side, its picture as large as the right half and about a third of the
## window's height allow.
func _lay_out() -> void:
	var room: Vector2 = get_tree().root.get_visible_rect().size
	var two: bool = reporting and room.x >= REPORT_LEFT + REPORT_GAP + REPORT_RIGHT + 120
	_box.vertical = not two
	var left: float = float(REPORT_LEFT) if two else (clampf(room.x - 80.0, 260.0, 520.0) if reporting else float(WIDE))
	var right: float = float(REPORT_RIGHT) if two else left
	_wide = left + REPORT_GAP + right if two else left
	for control: Control in [_said, _status]:
		control.custom_minimum_size.x = _wide
	_words.custom_minimum_size = Vector2(left, 96.0 if reporting else 110.0)
	_expected.custom_minimum_size.x = left
	_sends.custom_minimum_size.x = left
	for control: Control in [_version, _model, _log, _log_text]:
		control.custom_minimum_size.x = right
	_marks_row.custom_minimum_size.x = right
	if _picture != null:
		var tall: float = clampf(room.y * 0.32, 120.0, 320.0)
		var scale: float = minf(right / _picture.get_width(), tall / _picture.get_height())
		_marker.custom_minimum_size = Vector2(_picture.get_width(), _picture.get_height()) * scale
	_column.custom_minimum_size.x = _wide


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
	_scroll.custom_minimum_size = Vector2(_wide, minf(_column.get_combined_minimum_size().y,
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
	# Send feedback's: small, beside its words.
	_thumb.texture = ImageTexture.create_from_image(_picture) if _picture_on and not reporting else null
	_thumb.visible = _picture_on
	_remove.visible = _picture_on
	_add.visible = not _picture_on and _picture != null
	_picture_row.visible = _picture != null and not reporting
	_picture_words.text = ("A picture of the window as it was, %d × %d" % [_picture.get_width(),
		_picture.get_height()]) if _picture_on else "No picture."
	# A report's: large, to mark.
	_marker.visible = reporting and _picture_on
	_marks_row.visible = reporting and _picture != null
	_leave.text = "Leave the picture out" if _picture_on else "Put the picture back"
	_marks_changed()
	if visible:
		_fit.call_deferred()


func _marks_changed() -> void:
	var count: int = _marker.marks.size() if _marker != null else 0
	if _marks_words == null:
		return
	_marks_words.text = "No picture goes with it." if not _picture_on else (
		"Drag on the picture to mark the spot." if count == 0
		else ("1 mark. Drag again to add another." if count == 1 else "%d marks. Drag again to add another." % count))
	_clear.visible = _picture_on and count > 0
	_say_sends()


## Everything a report would send, in a line: what was written, and each
## thing that goes with it.
func _say_sends() -> void:
	if _sends_row == null:
		return
	_sends_row.visible = reporting
	if not reporting:
		return
	var parts: PackedStringArray = ["What you wrote"]
	if _picture_on:
		var count: int = _marker.marks.size()
		parts.append("the picture" if count == 0 else ("the picture, with 1 mark" if count == 1
			else "the picture, with %d marks" % count))
	if _version.button_pressed:
		parts.append("the version and your system")
	if _model.button_pressed and not _model.disabled:
		parts.append("the model, as a file")
	if _log.button_pressed and not _log.disabled:
		var lines: int = _log_text.text.count("\n") + 1
		parts.append("1 log line" if lines == 1 else "%d log lines" % lines)
	if not _error.is_empty():
		parts.append("the error it said")
	_sends.text = " · ".join(parts)


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
	var at: int = _kind_at()
	var kind: String = KINDS[at] if at >= 0 else ""
	var out: Dictionary = {"kind": kind, "words": _words.text.strip_edges(), "source": "app",
		"page": "web" if OS.has_feature("web") else "desktop"}
	if _email_row.visible:
		out["email"] = _email.text.strip_edges()
	var details: Dictionary = {}
	if _version.button_pressed:
		var size: Vector2i = get_tree().root.size
		details = {"version": BuildInfo.version(), "system": _system(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(), "window": "%dx%d" % [size.x, size.y]}
	if reporting:
		# Where it was asked from, the error a notice said, and the boxes
		# drawn, in the picture's pixels: what the report is about, never
		# anything of the person's.
		details["from"] = from
		if not _error.is_empty():
			details["error"] = _error
		if _picture_on and not _marker.marks.is_empty():
			details["marks"] = _marker.words()
		var expected: String = _expected.text.strip_edges()
		if _expected_row.visible and not expected.is_empty():
			out["expected"] = expected
	if not details.is_empty():
		out["details"] = details
	if _picture_on and _picture != null:
		var image: Image = _marker.marked() if reporting else _picture
		out["picture"] = {"type": "image/jpeg",
			"data": Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.85))}
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
	if reporting and not _signed_in():
		_status.text = "Sign in to send a report: Account, at the top right."
		return
	if str(asked["kind"]).is_empty():
		_status.text = "Choose what it is: something wrong, an idea or a question."
		return
	if str(asked["words"]).length() < 3:
		_status.text = "Say what happened." if reporting and asked["kind"] == "bug" \
			else "Say what happened, or what you would like."
		_words.grab_focus()
		return
	var long: int = str(asked["words"]).length() + str(asked.get("expected", "")).length()
	if long > MOST_WORDS or str(asked.get("expected", "")).length() > MOST_EXPECTED:
		_status.text = "At most %d characters; that is %d." % [MOST_WORDS, long]
		return
	if _email_row.visible and not "@" in str(asked.get("email", "")):
		_status.text = "Give an email address, so we can answer you."
		_email.grab_focus()
		return
	_sending = true
	get_ok_button().disabled = true
	_status.text = "Sending…"
	var token: String = ""
	if _signed_in():
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
	get_ok_button().text = "Close"
	_cancel.visible = false
	if reporting:
		_thank(said as Dictionary if said is Dictionary else {})
	else:
		_status.text = words if not words.is_empty() else "Thank you."
	_fit.call_deferred()


## A report gone: its number, where to follow it, and what of it did not go.
func _thank(said: Dictionary) -> void:
	var id: int = int(said.get("id", 0))
	_box.visible = false
	_said.text = ("Thank you. Report #%d is in." % id) if id > 0 else "Thank you. Your report is in."
	var attached: Dictionary = said.get("attached", {}) if said.get("attached") is Dictionary else {}
	var lost: String = ""
	if attached.get("picture") == false and attached.get("model") == false:
		lost = " The picture and the model did not go with it."
	elif attached.get("picture") == false:
		lost = " The picture did not go with it."
	elif attached.get("model") == false:
		lost = " The model did not go with it."
	_status.text = "We read every report ourselves. Follow it, and our answer, in Your reports." + lost
	_reports.visible = true


## Your reports on the site: this deployment's own on the web, so a preview
## opens its own.
func reports_link() -> String:
	var origin: String = Origin.here() if OS.has_feature("web") else ""
	return (origin if not origin.is_empty() else DocsPages.SITE) + REPORTS_PATH


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
	if _box.visible:
		for n: int in KINDS.size():
			out["feedback_" + KINDS[n]] = _kinds[n]
	if _email_row.visible:
		out["feedback_email"] = _email
	if _cancel.visible:
		out["feedback_cancel"] = _cancel
	if _remove.is_visible_in_tree():
		out["feedback_picture_remove"] = _remove
	if _add.is_visible_in_tree():
		out["feedback_picture_add"] = _add
	if _show_log.is_visible_in_tree():
		out["feedback_show_log"] = _show_log
	if _expected_row.is_visible_in_tree():
		out["report_expected"] = _expected
	if _marker.is_visible_in_tree():
		out["report_picture"] = _marker
	if _clear.is_visible_in_tree():
		out["report_clear_marks"] = _clear
	if _leave.is_visible_in_tree():
		out["report_picture_out" if _picture_on else "report_picture_back"] = _leave
	if _reports.visible:
		out["report_reports"] = _reports
	return out


## What it shows and what would go, for a probe and the page.
func page_state() -> Dictionary:
	return {"open": visible, "reporting": reporting, "from": from, "title": title,
		"email_asked": _email_row.visible if _email_row != null else false,
		"picture": _picture_on, "picture_size": [_picture.get_width(), _picture.get_height()] if _picture != null else [],
		"marks": _marker.words() if _marker != null else "",
		"version": _version.text if _version != null else "", "model": _model.text if _model != null else "",
		"log": _log.text if _log != null else "", "log_shown": _log_text.visible if _log_text != null else false,
		"sends": _sends.text if _sends != null and _sends_row.visible else "",
		"said": _said.text if _said != null else "",
		"status": _status.text if _status != null else "", "sent": int(last_answer.get("code", 0)) == 200,
		"answer": last_answer.get("body") if last_answer.get("body") is Dictionary else {}}
