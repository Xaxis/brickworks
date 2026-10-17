## This tab, as Claude knows it, and the Claude chats working in it.
##
## The owner (2026-10-17): with two Brickworks tabs on two projects and two
## Claude chats, how does a person tie each chat to its tab so they do not
## get in each other's way? So, where the person looks for Claude (Account,
## and the assistant panel's "Or with your Claude plan"):
##
##   - this tab's name to say to Claude: its id and its model's name;
##   - New chat for this tab: Claude opened on a new chat whose first
##     message names this tab (ClaudeConnector.start_chat), in claude.ai,
##     the Claude app or Claude Code;
##   - which chat works here, since when and what it did last; and, when
##     two do, that plainly, with Keep this one beside each: the other is
##     moved off and told so on its next call (api/mcp.js).
##
## The toolbar says the same in one quiet line ([method badge]).
class_name ClaudeTabView
extends VBoxContainer

var connector: ClaudeConnector

var _name: Label
var _chats: VBoxContainer
var _start: Button
var _ways: HBoxContainer
var _app: LinkButton
var _code: LinkButton
var _said: Label
var _command_row: HBoxContainer
var _command: LineEdit
var _keeps: Array[Button] = []

const WORKING := Color(0.35, 0.8, 0.45)
const TWO := Color(0.95, 0.72, 0.25)


func setup(with: ClaudeConnector) -> void:
	connector = with
	add_theme_constant_override("separation", 6)

	_name = _line("", 12, 0.85)
	_name.tooltip_text = "What Claude calls this tab. Say “the %s tab” in a chat to work here."
	add_child(_name)

	_chats = VBoxContainer.new()
	_chats.add_theme_constant_override("separation", 4)
	add_child(_chats)

	_start = Button.new()
	_start.text = "New chat for this tab"
	_start.focus_mode = Control.FOCUS_NONE
	_start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_start.tooltip_text = "Opens claude.ai on a new chat whose first message names this tab"
	_start.pressed.connect(func() -> void: _open("claude.ai"))
	add_child(_start)

	_ways = HBoxContainer.new()
	_ways.add_theme_constant_override("separation", 12)
	add_child(_ways)
	_ways.add_child(_line("Or in", 11, 0.7))
	_app = Look.link("the Claude app", 11)
	_app.tooltip_text = "Opens the Claude desktop app on a new chat for this tab"
	_app.pressed.connect(func() -> void: _open("app"))
	_ways.add_child(_app)
	_code = Look.link("Claude Code", 11)
	_code.tooltip_text = "A command line to paste: Claude Code starts a chat for this tab"
	_code.pressed.connect(func() -> void: _open("code"))
	_ways.add_child(_code)

	_said = _line("", 11, 0.75)
	_said.visible = false
	add_child(_said)
	_command_row = HBoxContainer.new()
	_command_row.add_theme_constant_override("separation", 6)
	_command_row.visible = false
	add_child(_command_row)
	_command = LineEdit.new()
	_command.editable = false
	_command.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_row.add_child(_command)
	var copy := Button.new()
	copy.text = "Copy"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_command.text)
		_said.text = "Copied. Paste it in a terminal.")
	_command_row.add_child(copy)

	connector.chats_changed.connect(func(_now: Array) -> void: show_now())
	connector.listening.connect(func(_on: bool, _address: String) -> void: show_now())
	connector.connections_changed.connect(func(_now: Array) -> void: show_now())
	# Its "2 min ago" kept true while it is on screen, twice a minute: never
	# every frame, which in a browser drawing in software costs whole seconds.
	var clock := Timer.new()
	clock.wait_time = 30.0
	clock.autostart = true
	clock.timeout.connect(func() -> void:
		if is_visible_in_tree():
			show_now())
	add_child(clock)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			show_now())
	show_now()


## Opened on Claude for this tab: [param where] is "claude.ai", "app" or "code".
func _open(where: String) -> void:
	connector.start_chat(where)
	_command_row.visible = where == "code"
	_command.text = connector.new_chat_command()
	_said.visible = true
	_said.text = {
		"claude.ai": "claude.ai has opened a new chat with its first message filled in, naming "
			+ "this tab. Add what to build and send it. The message is copied too, if the box is empty.",
		"app": "The Claude app opens on a new chat naming this tab, if it is installed. The first "
			+ "message is copied too: paste it into a new chat if nothing opened.",
		"code": "Run this in a terminal, in any folder: Claude Code starts a chat for this tab. "
			+ "It is copied.",
	}[where]


## Its controls, for the page and the probes to find.
func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var named: Dictionary = {prefix + "new_chat": _start, prefix + "new_chat_app": _app,
		prefix + "new_chat_code": _code}
	for n: int in _keeps.size():
		if _keeps[n].is_visible_in_tree():
			named[prefix + "keep_chat_%d" % n] = _keeps[n]
	return named


## Put before its controls' names, so two of these on screen differ.
var prefix: String = ""


## What it says, as it says it: for probes.
func words() -> String:
	var said := PackedStringArray([_name.text])
	for row: Node in _chats.get_children():
		for label: Node in row.find_children("*", "Label", true, false):
			said.append((label as Label).text)
		if row is Label:
			said.append((row as Label).text)
	return "\n".join(said)


func show_now() -> void:
	if connector == null:
		return
	var on: bool = connector.is_on()
	visible = on
	if not on:
		return
	var tab: String = connector.tab()
	_name.text = "This tab is %s. Say it to Claude to work here." % connector.tab_words()
	_name.tooltip_text = ("Claude knows this tab as %s. In a chat, say “the %s tab” "
		+ "(or its model's name) and Claude works here.") % [tab, tab]
	for child: Node in _chats.get_children():
		_chats.remove_child(child)
		child.queue_free()
	_keeps.clear()
	var now: Array = connector.working()
	if now.is_empty():
		_chats.add_child(_line("No Claude chat is working in this tab.", 11, 0.7))
	elif now.size() == 1:
		_chats.add_child(_dotted("A Claude chat is working here: %s." % chat_words(now[0]), WORKING))
	else:
		_chats.add_child(_dotted("%d Claude chats are working in this tab, on the one model. "
			% now.size() + "Keep one; the other is moved off and asked to choose another tab.", TWO))
		for one: Variant in now:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var words: Label = _line(chat_words(one).left(1).to_upper() + chat_words(one).substr(1), 11, 0.85)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(words)
			var keep := Button.new()
			keep.text = "Keep this one"
			keep.focus_mode = Control.FOCUS_NONE
			keep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var chat: String = str((one as Dictionary).get("chat", ""))
			keep.pressed.connect(func() -> void:
				keep.disabled = true
				if await connector.keep_chat(chat) < 0:
					keep.disabled = false
					_said.visible = true
					_said.text = "Could not reach Brickworks to keep it. Try again.")
			row.add_child(keep)
			_keeps.append(keep)
			_chats.add_child(row)
	_start.tooltip_text = "Opens claude.ai on a new chat whose first message names %s" % tab


## One chat, in words: "since 14:05, last Built “Castle”, 2 min ago".
static func chat_words(one: Variant) -> String:
	if not one is Dictionary:
		return ""
	var it: Dictionary = one
	var said: String = "since %s" % _clock(str(it.get("since", "")))
	var did: String = str(it.get("words", ""))
	if did.is_empty() and not str(it.get("did", "")).is_empty():
		did = ConnectorForm.said(str(it["did"]))
	if not did.is_empty():
		said += ", last: %s, %s" % [did.left(1).to_lower() + did.substr(1), _ago(str(it.get("last", "")))]
	return said


## The toolbar's line for this tab: [text, colour, tooltip], or ["", …]
## while the connector is off.
static func badge(connector: ClaudeConnector) -> Array:
	if connector == null or not connector.is_on():
		return ["", Color.TRANSPARENT, ""]
	var now: Array = connector.working()
	var tab: String = connector.tab()
	if now.size() >= 2:
		return ["%d Claude chats · tab %s" % [now.size(), tab], TWO,
			"%d Claude chats are working in this tab, on the one model. Open Account to keep one." % now.size()]
	if now.size() == 1:
		return ["Claude working · tab %s" % tab, WORKING,
			"A Claude chat is working in this tab: %s." % chat_words(now[0])]
	return ["Tab %s" % tab, Color(0.55, 0.57, 0.6),
		"Claude knows this tab as %s. No Claude chat is working in it. Account has New chat for this tab." % tab]


## The time of day, here, of an ISO time from the relay (UTC).
static func _clock(iso: String) -> String:
	if iso.length() < 19:
		return "just now"
	var utc: int = int(Time.get_unix_time_from_datetime_string(iso.substr(0, 19)))
	var local: int = utc + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var then: Dictionary = Time.get_datetime_dict_from_unix_time(local)
	return "%02d:%02d" % [then.hour, then.minute]


static func _ago(iso: String) -> String:
	if iso.length() < 19:
		return "just now"
	var s: int = int(Time.get_unix_time_from_system()) \
		- int(Time.get_unix_time_from_datetime_string(iso.substr(0, 19)))
	if s < 60:
		return "just now"
	if s < 5400:
		return "%d min ago" % roundi(s / 60.0)
	return "%d h ago" % roundi(s / 3600.0)


func _dotted(text: String, colour: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = colour
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var label: Label = _line(text, 11, 0.9)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label
