## The comments on one step of a shared model (2026-10-18, api/people.js
## ?op=comments, supabase/comments.sql): a small count on the step, and
## the step's comments when it is tapped, with a box to add one there for
## somebody who may.
##
## Used twice: on the viewer (ShareView), for the step the timeline is on,
## and in the step player on phones (BuildMode), for the page shown. Step 0
## is the whole model: the viewer with the timeline away or at either end,
## and the step player's cover. There the comments on the model itself are
## listed, and with them any made on a step that has changed since, each
## saying which step of which version it was on; a comment written there is
## on the model, not on a step.
##
## A step's comments are the ones the server says show on it ([code]
## on_step[/code]): made on this step of this version, or of another version
## whose steps up to this one are as they were. One made on an older version
## says so ("On step 7 of version 1, an older one").
##
## Everything a person typed is a Label's text: never BBCode, never a link.
## Who may write is the server's to say ([code]you[/code]: signed in, 13 or
## over, not barred, the model's comments on), and when they may not, its
## words are said in place of the box, with a way to the model's page to
## sign in when nobody is. This only shows and says what was pressed:
## main.gd asks the server and sends (_comments_for_view).
class_name StepComments
extends Control

## The count was tapped and the step's comments are up: main.gd may find
## out who is here now (a kept session is only read then).
signal opened
## Send [param body] as a comment on [param step] (0: the whole model).
signal send_wanted(step: int, body: String)
## The model's page, to sign in there.
signal page_wanted

## The most a comment says, as the server takes it.
const LONGEST := 1000

## "view" on the viewer, "build" in the step player: the names its controls
## go by for a check (controls_by_name).
var prefix: String = "view"
## The step showing; 0 the whole model.
var step: int = 0
## The answer as the server gave it: every comment, oldest first.
var comments: Array = []
var you: Dictionary = {}
## Whether the model takes comments (its builder can turn them off).
var taking: bool = true
## Whether an answer came at all: before one, or without a server that has
## comments, nothing is shown.
var known: bool = false
## Who is here is being found out (a kept session renewed, asked again).
var asking: bool = false
## Where the panel may go, in the host's coordinates: the part of the
## window the model is seen in.
var area: Callable = Callable()

## The count, to put on the step: the host adds it where it belongs.
var pill: Button
var _panel: PanelContainer
var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _write: HBoxContainer
var _box: LineEdit
var _send: Button
var _why: Label
var _sign_in: Button
var _said: Label
var _close: Button
var _pt: float = 1.0
var _shown: Array = []
var _sending: bool = false

const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
	"Oct", "Nov", "Dec"]


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill = Button.new()
	pill.focus_mode = Control.FOCUS_NONE
	pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pill.tooltip_text = "The comments on this step"
	pill.visible = false
	pill.pressed.connect(toggle)
	# Under the panel, which comes up over it; a host may move it (BuildMode
	# puts it in its top bar).
	add_child(pill)
	_build_panel()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# A finger dragged on the panel scrolls it or does nothing: never turns
	# the model behind (CadCamera takes what no control accepted).
	_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenDrag or event is InputEventScreenTouch \
				or event is InputEventMouseButton:
			_panel.accept_event())
	add_child(_panel)
	var column := VBoxContainer.new()
	column.name = "Column"
	_panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	_close = _button("Close", "Back to the step")
	_close.pressed.connect(close)
	head.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_why = Label.new()
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.modulate = Color(1.0, 0.86, 0.45)
	column.add_child(_why)
	_sign_in = _button("Open its page to sign in", "The model's page on brickworks.diy, "
		+ "where you can sign in and comment")
	_sign_in.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_sign_in.pressed.connect(func() -> void: page_wanted.emit())
	column.add_child(_sign_in)
	_write = HBoxContainer.new()
	column.add_child(_write)
	_box = LineEdit.new()
	_box.max_length = LONGEST
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.placeholder_text = "Add a comment"
	_box.text_submitted.connect(func(_text: String) -> void: _sent_pressed())
	_write.add_child(_box)
	_send = _button("Send", "Add your comment on this step")
	_send.pressed.connect(_sent_pressed)
	_write.add_child(_send)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.modulate = Color(1, 1, 1, 0.75)
	column.add_child(_said)


func _button(words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


## Sized in points ([param pt] interface units to a point): words a phone
## can read, buttons a finger can press. [param pill_points] is the
## count's own size, smaller on the viewer's line than in the step player.
func fit(pt: float, pill_points: float = 16.0) -> void:
	_pt = maxf(pt, 0.1)
	pill.add_theme_font_size_override("font_size", roundi(pill_points * _pt))
	pill.custom_minimum_size = Vector2(0.0, roundi(pill_points * 2.4 * _pt))
	_face(pill, Color(1, 1, 1, 0.12))
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.10, 0.12, 0.97)
	backing.border_color = Color(1, 1, 1, 0.16)
	backing.set_border_width_all(maxi(1, roundi(_pt)))
	backing.set_corner_radius_all(roundi(10.0 * _pt))
	backing.set_content_margin_all(12.0 * _pt)
	_panel.add_theme_stylebox_override("panel", backing)
	(_panel.get_node("Column") as VBoxContainer).add_theme_constant_override("separation", roundi(8.0 * _pt))
	_list.add_theme_constant_override("separation", roundi(10.0 * _pt))
	_write.add_theme_constant_override("separation", roundi(8.0 * _pt))
	_title.add_theme_font_size_override("font_size", roundi(18.0 * _pt))
	for words: Label in [_why, _said]:
		words.add_theme_font_size_override("font_size", roundi(15.0 * _pt))
	_box.add_theme_font_size_override("font_size", roundi(16.0 * _pt))
	_box.custom_minimum_size = Vector2(0.0, 44.0 * _pt)
	for button: Button in [_close, _send, _sign_in]:
		button.add_theme_font_size_override("font_size", roundi(16.0 * _pt))
		button.custom_minimum_size = Vector2(0.0, 44.0 * _pt)
		_face(button, Color(0.78, 0.06, 0.18) if button == _send else Color(1, 1, 1, 0.12))
	if _panel.visible:
		_fill()


func _face(button: Button, colour: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = colour.lightened({"normal": 0.0, "hover": 0.12, "pressed": 0.2,
			"disabled": 0.0}[state])
		if state == "disabled":
			face.bg_color.a *= 0.4
		face.border_color = Color(1, 1, 1, 0.2)
		face.set_border_width_all(maxi(1, roundi(_pt)))
		face.set_corner_radius_all(roundi(8.0 * _pt))
		face.content_margin_left = 12.0 * _pt
		face.content_margin_right = 12.0 * _pt
		button.add_theme_stylebox_override(state, face)


## The server's answer ({comments, you, open}), or an empty one for none:
## no server with comments, or it did not answer.
func show_answer(answer: Dictionary) -> void:
	known = not answer.is_empty()
	comments = answer["comments"] if answer.get("comments") is Array else []
	you = answer["you"] if answer.get("you") is Dictionary else {}
	taking = answer.get("open", true) != false
	_redraw()


## The step showing: 0 the whole model.
func set_step(at: int) -> void:
	if at == step:
		return
	step = maxi(at, 0)
	# A step moved on from is a step left: its comments go with it.
	if _panel.visible:
		close()
	_redraw()


## The comments of the step showing.
func on_step() -> Array:
	var out: Array = []
	for one: Variant in comments:
		if not one is Dictionary:
			continue
		var on: Variant = (one as Dictionary).get("on_step")
		var at: int = int(on) if (on is int or on is float) else 0
		if at == step:
			out.append(one)
	return out


func count() -> int:
	return on_step().size()


func _redraw() -> void:
	var n: int = count()
	pill.text = "Comment" if n == 0 else ("1 comment" if n == 1 else "%d comments" % n)
	pill.tooltip_text = ("The comments on the whole model" if step == 0
		else "The comments on step %d" % step)
	pill.visible = known and (n > 0 or taking)
	if _panel.visible:
		_fill()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	if _panel.visible:
		close()
	else:
		open()


func open() -> void:
	if not known:
		return
	_said.text = ""
	_panel.visible = true
	_fill()
	opened.emit()


func close() -> void:
	_panel.visible = false
	if _box.has_focus():
		_box.release_focus()
	set_process(false)


## The panel's words: the step's comments, then the box or why there is none.
func _fill() -> void:
	_title.text = "The whole model" if step == 0 else "Step %d" % step
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_shown = on_step()
	var wide: float = _width() - 24.0 * _pt
	for one: Variant in _shown:
		_list.add_child(_entry(one as Dictionary, wide))
	if _shown.is_empty():
		var none := Label.new()
		none.text = "No comments on the whole model yet." if step == 0 \
			else "No comments on this step yet."
		none.modulate = Color(1, 1, 1, 0.6)
		none.add_theme_font_size_override("font_size", roundi(15.0 * _pt))
		_list.add_child(none)
	var may: bool = bool(you.get("may_write", false))
	_write.visible = may and not asking
	_why.text = "One moment…" if asking else ("" if may else str(you.get("why_not", "")))
	if not asking and not may and _why.text.is_empty():
		_why.text = "Comments cannot be added here just now."
	_why.visible = not _why.text.is_empty()
	# Nobody signed in: the model's page signs people in.
	_sign_in.visible = not asking and not may and not bool(you.get("signed_in", false)) and taking
	_send.disabled = _sending
	_box.custom_minimum_size.x = 0.0
	_said.visible = not _said.text.is_empty()
	set_process(true)
	_place()


func _entry(one: Dictionary, wide: float) -> Control:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", roundi(2.0 * _pt))
	var head := Label.new()
	var who: String = str(one.get("by", "")) if one.get("by") is String else ""
	var bits: Array[String] = [who if not who.is_empty() else "A builder"]
	if bool(one.get("by_owner", false)):
		bits.append("its builder")
	var when: String = _day(str(one.get("at", "")))
	if not when.is_empty():
		bits.append(when)
	if one.get("edited_at") is String:
		bits.append("edited")
	if bool(one.get("hidden", false)):
		bits.append("hidden from others")
	head.text = " · ".join(bits)
	head.modulate = Color(1, 1, 1, 0.65)
	head.add_theme_font_size_override("font_size", roundi(13.0 * _pt))
	entry.add_child(head)
	# Where it was made, when that is not this step of this version.
	var where: String = _where(one)
	if not where.is_empty():
		var said := Label.new()
		said.text = where
		said.modulate = Color(1.0, 0.86, 0.45)
		said.add_theme_font_size_override("font_size", roundi(13.0 * _pt))
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size = Vector2(wide, 0.0)
		entry.add_child(said)
	var body := Label.new()
	body.text = str(one.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(wide, 0.0)
	body.add_theme_font_size_override("font_size", roundi(16.0 * _pt))
	entry.add_child(body)
	return entry


## "On step 7 of version 1, an older one", for a comment made on an older
## version, or listed on the whole model from a step that changed since.
func _where(one: Dictionary) -> String:
	var said: String = str(one.get("said", ""))
	var older: bool = bool(one.get("older", false))
	var on_a_step: bool = one.get("step") is int or one.get("step") is float
	if said.is_empty() or not (older or (step == 0 and on_a_step)):
		return ""
	said = said.substr(0, 1).to_upper() + said.substr(1)
	return said + (", an older one" if older and not said.contains("older") else "")


static func _day(iso: String) -> String:
	if iso.length() < 10:
		return ""
	var month: int = iso.substr(5, 2).to_int()
	if month < 1 or month > 12:
		return ""
	return "%d %s %s" % [iso.substr(8, 2).to_int(), MONTHS[month - 1], iso.substr(0, 4)]


func _width() -> float:
	var room: Rect2 = area.call() if area.is_valid() else Rect2(Vector2.ZERO, size)
	return maxf(minf(room.size.x - 20.0 * _pt, 460.0 * _pt), 160.0 * _pt)


## Low in the part of the window the model is seen in, as a sheet comes up
## from the bottom of a phone, no taller than most of it.
func _place() -> void:
	var room: Rect2 = area.call() if area.is_valid() else Rect2(Vector2.ZERO, size)
	var wide: float = _width()
	var listed: float = _list.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(wide - 24.0 * _pt, minf(listed, maxf(room.size.y * 0.5, 80.0)))
	_panel.custom_minimum_size = Vector2(wide, 0.0)
	_panel.reset_size()
	var tall: float = minf(_panel.size.y, room.size.y - 12.0 * _pt)
	var spot := Vector2(room.position.x + (room.size.x - wide) * 0.5,
		room.end.y - tall - 10.0 * _pt) - global_position
	if _panel.position != spot:
		_panel.position = spot


func _process(_delta: float) -> void:
	if not _panel.visible:
		set_process(false)
		return
	_place()


func _sent_pressed() -> void:
	var body: String = _box.text.strip_edges()
	if body.is_empty() or _sending:
		return
	_sending = true
	_send.disabled = true
	_said.text = "Sending…"
	_said.visible = true
	send_wanted.emit(step, body)


## The comment was kept (main.gd has put it in the answer shown): the box
## emptied.
func sent() -> void:
	_sending = false
	_box.text = ""
	_said.text = "Added."
	_redraw()


## Not kept, and why, in the server's words.
func refused(words: String) -> void:
	_sending = false
	_said.text = words
	_redraw()


func covers(point: Vector2) -> bool:
	return (_panel.is_visible_in_tree() and _panel.get_global_rect().has_point(point)) \
		or (pill.is_visible_in_tree() and pill.get_global_rect().has_point(point))


func controls_by_name() -> Dictionary:
	var named: Dictionary = {}
	if pill.is_visible_in_tree():
		named[prefix + "_comments"] = pill
	if _panel.is_visible_in_tree():
		named[prefix + "_comment_close"] = _close
		if _write.visible:
			named[prefix + "_comment_box"] = _box
			named[prefix + "_comment_send"] = _send
		if _sign_in.visible:
			named[prefix + "_comment_sign_in"] = _sign_in
	return named


func page_state() -> Dictionary:
	var bodies: Array = []
	var where: Array = []
	if _panel.visible:
		for one: Variant in _shown:
			bodies.append(str((one as Dictionary).get("body", "")))
			where.append(_where(one as Dictionary))
	return {"comments": count() if known else 0, "comments_open": _panel.visible,
		"comments_shown": bodies, "comments_where": where, "comment_why_not": _why.text if _panel.visible and _why.visible else "",
		"comment_can_write": _panel.visible and _write.visible,
		"comment_said": _said.text if _panel.visible else "", "comment_pill": pill.text if pill.visible else ""}
