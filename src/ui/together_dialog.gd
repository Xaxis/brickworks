## File, Build together…: build the model on the baseplate with somebody
## else, live, each in their own browser or desktop app (Together).
##
## Before a session: Start, which gives a link to send, or a link someone
## sent pasted in to join theirs. In one: the link, who is in it and whether
## each is here, and End the session (the owner's, with Remove beside each
## person) or Leave. The look of Versions, the panel beside it in the menu.
class_name TogetherDialog
extends AcceptDialog

var together: Together

var _note: Label
var _start: Button
var _join_row: HBoxContainer
var _join_field: LineEdit
var _join: Button
var _link_row: HBoxContainer
var _link: LineEdit
var _copy: Button
var _rows: VBoxContainer
var _end: Button
var _removes: Array[Button] = []
var _chat_box: VBoxContainer
var _chat_lines: Label
var _chat_row: HBoxContainer
var _chat_field: LineEdit
var _chat_send: Button
var _chat_note: Label
## The chat lines shown, the newest last.
const CHAT_SHOWN := 8
var _busy: bool = false

const WIDTH := 440


func _ready() -> void:
	title = "Build together"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(column)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(_note)
	_start = Button.new()
	_start.text = "Start a session"
	_start.focus_mode = Control.FOCUS_NONE
	_start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_start.tooltip_text = "Make a link for this model that someone signed in can open to build it with you"
	_start.pressed.connect(_on_start)
	column.add_child(_start)
	_join_row = HBoxContainer.new()
	_join_row.add_theme_constant_override("separation", 8)
	_join_field = LineEdit.new()
	_join_field.placeholder_text = "Or paste a link someone sent you"
	_join_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_field.text_submitted.connect(func(_text: String) -> void: _on_join())
	_join_row.add_child(_join_field)
	_join = Button.new()
	_join.text = "Join"
	_join.focus_mode = Control.FOCUS_NONE
	_join.pressed.connect(_on_join)
	_join_row.add_child(_join)
	column.add_child(_join_row)
	_link_row = HBoxContainer.new()
	_link_row.add_theme_constant_override("separation", 8)
	_link = LineEdit.new()
	_link.editable = false
	_link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_link_row.add_child(_link)
	_copy = Button.new()
	_copy.text = "Copy link"
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(together.link)
		_copy.text = "Copied")
	_link_row.add_child(_copy)
	column.add_child(_link_row)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	column.add_child(_rows)
	# A short chat, under who is here.
	_chat_box = VBoxContainer.new()
	_chat_box.add_theme_constant_override("separation", 6)
	_chat_lines = Label.new()
	_chat_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_lines.custom_minimum_size = Vector2(WIDTH, 0)
	_chat_box.add_child(_chat_lines)
	_chat_row = HBoxContainer.new()
	_chat_row.add_theme_constant_override("separation", 8)
	_chat_field = LineEdit.new()
	_chat_field.placeholder_text = "Say something to the others"
	_chat_field.max_length = 280
	_chat_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_field.text_submitted.connect(func(_text: String) -> void: _on_chat())
	_chat_row.add_child(_chat_field)
	_chat_send = Button.new()
	_chat_send.text = "Send"
	_chat_send.focus_mode = Control.FOCUS_NONE
	_chat_send.pressed.connect(_on_chat)
	_chat_row.add_child(_chat_send)
	_chat_box.add_child(_chat_row)
	_chat_note = Label.new()
	_chat_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_note.custom_minimum_size = Vector2(WIDTH, 0)
	_chat_box.add_child(_chat_note)
	column.add_child(_chat_box)
	_end = Button.new()
	_end.focus_mode = Control.FOCUS_NONE
	_end.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_end.pressed.connect(_on_end)
	column.add_child(_end)
	together.changed.connect(func() -> void:
		if visible:
			fill())


## Show the session, or how to start or join one.
func open() -> void:
	fill()
	popup_centered()


## What it says and shows, for the session as it is now.
func fill() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_removes.clear()
	var live: bool = together.live
	_start.visible = not live
	_join_row.visible = not live
	_link_row.visible = live
	_end.visible = live
	_chat_box.visible = live
	_start.disabled = _busy
	_join.disabled = _busy
	if not live:
		_note.text = ("Build this model with someone else, live, each in your own browser or the "
			+ "app. Start a session and send them its link; they sign in and join. Each of you "
			+ "sees the other's parts as they go down, and your Undo takes back only your own.")
		if not together.ended_words.is_empty():
			_note.text = together.ended_words + "\n\n" + _note.text
		return
	_link.text = together.link
	_copy.text = "Copy link"
	var others: int = 0
	for person: Variant in together.people:
		if not (person as Dictionary).get("me", false):
			others += 1
	if together.owns:
		_note.text = ("Send this link to whoever you are building with. Anyone signed in who has it "
			+ "can join until you end the session; the model stays yours and saves as usual.")
		_end.text = "End the session"
	else:
		_note.text = ("You are building “%s” with %s. Your Undo takes back only your own changes.") \
			% [together.store.title, "the others" if others != 1 else "one other"]
		_end.text = "Leave"
	for item: Variant in together.people:
		var person: Dictionary = item
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var words := Label.new()
		var who: String = str(person.get("name", ""))
		if bool(person.get("me", false)):
			who += " (you)"
		elif bool(person.get("owner", false)) and who != "The owner":
			who += " (its owner)"
		words.text = "%s  ·  %s" % [who, "here" if bool(person.get("here", false)) else "away"]
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		if together.owns and not bool(person.get("me", false)):
			var take_out := Button.new()
			take_out.text = "Remove"
			take_out.focus_mode = Control.FOCUS_NONE
			take_out.tooltip_text = "Take them out of the session; the link no longer lets them in"
			take_out.pressed.connect(func() -> void: together.remove(str(person.get("who", ""))))
			row.add_child(take_out)
			_removes.append(take_out)
		_rows.add_child(row)
	_fill_chat()


## The last lines of the chat, and the field to say one; or why not.
func _fill_chat() -> void:
	var lines := PackedStringArray()
	var shown: Array = together.messages.slice(maxi(0, together.messages.size() - CHAT_SHOWN))
	for line: Variant in shown:
		lines.append("%s: %s" % [(line as Dictionary).get("name", ""), (line as Dictionary).get("text", "")])
	_chat_lines.text = "\n".join(lines)
	_chat_lines.visible = not lines.is_empty()
	var allowed: bool = together.chat_words.is_empty()
	_chat_row.visible = allowed
	_chat_note.visible = not allowed
	_chat_note.text = together.chat_words


func _on_chat() -> void:
	if _chat_field.text.strip_edges().is_empty():
		return
	var trouble: String = together.chat(_chat_field.text)
	if trouble.is_empty():
		_chat_field.text = ""
	else:
		together.said.emit(trouble)


func _on_start() -> void:
	_busy = true
	fill()
	var trouble: String = await together.start()
	_busy = false
	if not trouble.is_empty():
		together.said.emit(trouble)
	fill()


func _on_join() -> void:
	# Enter in the field with nothing in it, or not a link, joins nothing
	# and keeps the panel up, saying so.
	if Together.secret_in(_join_field.text).is_empty():
		if not _join_field.text.strip_edges().is_empty():
			_note.text = "That is not a Build together link. Paste the whole link you were sent."
		return
	_busy = true
	fill()
	hide()
	var trouble: String = await together.join(_join_field.text)
	_busy = false
	if not trouble.is_empty():
		together.said.emit(trouble)
	else:
		_join_field.text = ""
		open()


func _on_end() -> void:
	if together.owns:
		await together.end()
	else:
		await together.leave()
	fill()


## What a browser check presses.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"together_close": get_ok_button()}
	if _start.is_visible_in_tree():
		out["together_start"] = _start
		out["together_join_field"] = _join_field
		out["together_join"] = _join
	if _link_row.is_visible_in_tree():
		out["together_copy"] = _copy
		out["together_end"] = _end
	if _chat_row.is_visible_in_tree():
		out["together_chat_field"] = _chat_field
		out["together_chat_send"] = _chat_send
	for n: int in _removes.size():
		out["together_remove_%d" % (n + 1)] = _removes[n]
	return out


## What it says, for a probe.
func page_state() -> Dictionary:
	return {"open": visible, "note": _note.text if _note != null else ""}
