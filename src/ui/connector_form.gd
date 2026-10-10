## Design on your Claude plan: this tab, offered to Claude as a connector.
##
## The other way in besides an API key. Someone on Claude Pro or Max turns
## it on, adds the address it shows to Claude — claude.ai or the Claude app
## as a custom connector, or Claude Code — and asks Claude to build.
## Claude, signed in its own way on their own plan, calls this app's tools;
## the model is built here, in the tab, where they watch it. Brickworks
## never sees a login, a token or a key, and never calls a model: Claude is
## the client, which is ordinary use of Anthropic's own apps.
##
## The brief is typed in Claude, not here — the one thing about this mode
## that has to be said plainly, because everything else in the panel takes
## a brief.
class_name ConnectorForm
extends VBoxContainer

var connector: ClaudeConnector

var _intro: Label
var _turn_on: Button
var _on_box: VBoxContainer
var _address: LineEdit
var _copied: Label
var _status: Label
var _activity: VBoxContainer
var _calls: int = 0
var _since: int = 0


func setup(with: ClaudeConnector) -> void:
	connector = with
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Or use your Claude plan"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	_intro = Label.new()
	_intro.text = ("On Claude Pro or Max? No key needed: add this tab to "
		+ "Claude as a connector, then ask Claude to build. It builds here, "
		+ "on your plan's usage. Nothing to install.")
	_intro.add_theme_font_size_override("font_size", 12)
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.modulate = Color(1, 1, 1, 0.8)
	add_child(_intro)

	_turn_on = Button.new()
	_turn_on.text = "Connect Claude"
	_turn_on.custom_minimum_size = Vector2(0, 34)
	_turn_on.focus_mode = Control.FOCUS_NONE
	_turn_on.pressed.connect(func() -> void: connector.start())
	add_child(_turn_on)

	_on_box = VBoxContainer.new()
	_on_box.add_theme_constant_override("separation", 6)
	_on_box.visible = false
	add_child(_on_box)

	var first := _line("1. Copy this tab's private address:", 12, 0.85)
	_on_box.add_child(first)
	var row := HBoxContainer.new()
	_on_box.add_child(row)
	_address = LineEdit.new()
	_address.editable = false
	_address.secret = false
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.tooltip_text = ("Anyone with this address can build in this "
		+ "tab while it is on — keep it to yourself. Turning it off ends it.")
	row.add_child(_address)
	var copy := Button.new()
	copy.text = "Copy"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_address.text)
		_copied.visible = true)
	row.add_child(copy)
	_copied = _line("Copied.", 11, 0.7)
	_copied.visible = false
	_on_box.add_child(_copied)

	_on_box.add_child(_line("2. Add it to Claude:", 12, 0.85))
	_on_box.add_child(_line("• claude.ai or the Claude app: in Settings, "
		+ "Connectors, choose Add custom connector and paste it.", 12, 0.8))
	_on_box.add_child(_line("• Claude Code: claude mcp add --transport http "
		+ "brickworks \"<the address>\"", 12, 0.8))
	_on_box.add_child(_line("3. In Claude, ask: “Build a small red house in "
		+ "Brickworks.” Keep this tab open; the model appears here.", 12, 0.85))

	_status = _line("", 12, 0.75)
	_on_box.add_child(_status)
	_activity = VBoxContainer.new()
	_activity.add_theme_constant_override("separation", 2)
	_on_box.add_child(_activity)

	var off := Button.new()
	off.text = "Turn off, and forget this address"
	off.flat = true
	off.focus_mode = Control.FOCUS_NONE
	off.add_theme_font_size_override("font_size", 12)
	off.pressed.connect(func() -> void: connector.stop())
	_on_box.add_child(off)

	connector.listening.connect(_on_listening)
	connector.called.connect(_on_called)
	connector.trouble.connect(func(why: String) -> void: _status.text = why)


func is_on() -> bool:
	return connector != null and connector.is_on()


func controls_by_name() -> Dictionary:
	return {"connect_claude": _turn_on, "connector_address": _address}


func _on_listening(on: bool, address: String) -> void:
	_turn_on.visible = not on
	_on_box.visible = on
	_address.text = address
	_copied.visible = false
	_calls = 0
	for child: Node in _activity.get_children():
		child.queue_free()
	_status.text = "Waiting for Claude…" if on else ""


## What Claude is doing, as it does it: the tool it just called and how
## many it has called. The model itself is the main report — it is being
## built on the baseplate as this updates.
func _on_called(tool: String) -> void:
	if tool.is_empty():
		_status.text = "Claude is connected."
		return
	_calls += 1
	if _calls == 1:
		_since = Time.get_ticks_msec()
	var seconds: int = (Time.get_ticks_msec() - _since) / 1000
	_status.text = "Claude is building — %d call%s, %d:%02d" % [_calls,
		"" if _calls == 1 else "s", seconds / 60, seconds % 60]
	var line := _line("· " + _said(tool), 11, 0.6)
	_activity.add_child(line)
	while _activity.get_child_count() > 6:
		var oldest: Node = _activity.get_child(0)
		_activity.remove_child(oldest)
		oldest.queue_free()


static func _said(tool: String) -> String:
	match tool:
		"search_parts": return "looked up parts"
		"check_design": return "checked a design"
		"submit_design": return "built a design"
		"edit_model": return "changed the model"
		"look_at_model": return "read what is built"
		"view_model": return "looked at the model"
		"clear_model": return "cleared the baseplate"
		"save_model": return "saved the model"
		"show_technique": return "looked up a technique"
		"attachment_points": return "worked out where a part attaches"
	return tool.replace("_", " ")


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label
