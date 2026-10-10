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
var _turn_on: CheckButton
var _state_row: HBoxContainer
var _dot: ColorRect
var _status: Label
var _steps_toggle: Button
var _on_box: VBoxContainer
var _address: LineEdit
var _copied: Label
var _copy: Button
var _in_view: Label
var _new_address: Button
var _calls: int = 0
var _since: int = 0
var _heard: String = ""
var _clock: Timer

const WAITING := Color(0.95, 0.72, 0.25)
const CONNECTED := Color(0.35, 0.8, 0.45)
const TROUBLE := Color(0.95, 0.4, 0.35)
const OFF := Color(0.55, 0.57, 0.6)


func setup(with: ClaudeConnector) -> void:
	connector = with
	add_theme_constant_override("separation", 8)

	add_child(HSeparator.new())
	# A switch, because that is what it is: on, Claude can reach this tab;
	# off, it cannot. It was a button that turned into a list of steps,
	# and nothing on the panel changed when Claude actually connected.
	var head := HBoxContainer.new()
	add_child(head)
	var title := Label.new()
	title.text = "Or with your Claude plan"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_turn_on = CheckButton.new()
	_turn_on.focus_mode = Control.FOCUS_NONE
	_turn_on.tooltip_text = "Let Claude build in this tab, or stop it"
	_turn_on.toggled.connect(func(on: bool) -> void:
		if on:
			connector.start()
		else:
			connector.stop())
	head.add_child(_turn_on)

	_intro = _line("On Claude Pro or Max, no key needed: connect this tab "
		+ "to Claude, then ask Claude to build. It builds here, on your "
		+ "plan's usage.", 11, 0.8)
	add_child(_intro)

	_state_row = HBoxContainer.new()
	_state_row.add_theme_constant_override("separation", 8)
	add_child(_state_row)
	_dot = ColorRect.new()
	_dot.custom_minimum_size = Vector2(9, 9)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_state_row.add_child(_dot)
	_status = _line("", 13, 1.0)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_state_row.add_child(_status)

	_steps_toggle = Button.new()
	_steps_toggle.flat = true
	_steps_toggle.focus_mode = Control.FOCUS_NONE
	_steps_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_steps_toggle.add_theme_font_size_override("font_size", 11)
	_steps_toggle.pressed.connect(func() -> void:
		_on_box.visible = not _on_box.visible
		_show())
	add_child(_steps_toggle)

	_on_box = VBoxContainer.new()
	_on_box.add_theme_constant_override("separation", 6)
	add_child(_on_box)

	_on_box.add_child(_line("1. Copy this tab's private address:", 12, 0.85))
	var row := HBoxContainer.new()
	_on_box.add_child(row)
	_address = LineEdit.new()
	_address.editable = false
	_address.secret = false
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.tooltip_text = ("Anyone with this address can build in this "
		+ "tab while it is on — keep it to yourself.")
	row.add_child(_address)
	_copy = Button.new()
	_copy.text = "Copy"
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_address.text)
		_copied.visible = true)
	row.add_child(_copy)
	_copied = _line("Copied. It stays the same on this browser, so you only "
		+ "add it once.", 11, 0.7)
	_copied.visible = false
	_on_box.add_child(_copied)
	_on_box.add_child(_line("2. Add it to Claude:", 12, 0.85))
	_on_box.add_child(_line("• claude.ai or the Claude app: Settings, "
		+ "Connectors, Add custom connector, and paste it.", 12, 0.8))
	_on_box.add_child(_line("• Claude Code: claude mcp add --transport http "
		+ "brickworks \"<the address>\"", 12, 0.8))
	_on_box.add_child(_line("3. In a chat with the connector on, ask: “Build a "
		+ "small red house in Brickworks.”", 12, 0.85))

	# The one thing about this way that surprises people, said where they
	# will be when it matters.
	_in_view = _line("Keep this tab in view while Claude builds: a browser "
		+ "pauses a tab it is not showing. Side by side with Claude works "
		+ "best, and you can watch it build.", 11, 0.7)
	add_child(_in_view)

	_new_address = Button.new()
	_new_address.text = "Make a new address"
	_new_address.flat = true
	_new_address.focus_mode = Control.FOCUS_NONE
	_new_address.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_new_address.add_theme_font_size_override("font_size", 11)
	_new_address.tooltip_text = ("If the address got out. The old one stops "
		+ "working, and you will need to add the new one to Claude instead.")
	_new_address.pressed.connect(func() -> void: connector.forget())
	add_child(_new_address)

	_clock = Timer.new()
	_clock.wait_time = 1.0
	_clock.timeout.connect(_tick)
	add_child(_clock)

	connector.listening.connect(_on_listening)
	connector.called.connect(_on_called)
	connector.trouble.connect(func(why: String) -> void:
		_say(why, TROUBLE))
	connector.relay_ok.connect(_settle)
	connector.replaced.connect(func() -> void:
		_say("Another Brickworks tab took this connector over. Switch it on "
			+ "here to take it back.", OFF))
	_on_listening(connector.is_on(), connector.address())


func is_on() -> bool:
	return connector != null and connector.is_on()


func controls_by_name() -> Dictionary:
	return {"connect_claude": _turn_on, "connector_address": _address,
		"connector_copy": _copy}


func _on_listening(on: bool, address: String) -> void:
	_turn_on.set_pressed_no_signal(on)
	_address.text = address
	_copied.visible = false
	_calls = 0
	_heard = ""
	# The steps while Claude has never reached this address; folded away
	# once it has, because then they are done.
	_on_box.visible = on and not connector.used()
	_settle()


## The state line for where things stand, when nothing newer has said it.
func _settle() -> void:
	if not connector.is_on():
		_say("Off. Claude cannot reach this tab." if not connector.address()
			.is_empty() else "", OFF)
	elif _calls > 0:
		_tick()
	elif not _heard.is_empty():
		_say("Connected — Claude reached this tab at %s." % _heard, CONNECTED)
	elif connector.used():
		_say("Connected. Waiting for Claude to call.", CONNECTED)
	else:
		_say("On. Waiting for Claude — add the address below.", WAITING)
	_show()


## Claude reached the tab: a tool by name, or "" for the handshake and
## the tool list, which is Claude connecting.
func _on_called(tool: String, _arguments: Dictionary) -> void:
	var now: Dictionary = Time.get_time_dict_from_system()
	_heard = "%02d:%02d" % [now.hour, now.minute]
	_on_box.visible = false
	if tool.is_empty():
		if _calls == 0:
			_say("Connected — Claude reached this tab at %s." % _heard, CONNECTED)
		_show()
		return
	_calls += 1
	if _calls == 1:
		_since = Time.get_ticks_msec()
		_clock.start()
	_tick()
	_show()


## How much Claude has done, and for how long. Each step is told in the
## conversation above, on a card like the app's own designs get; the model
## itself is the main report, built on the baseplate as this updates.
func _tick() -> void:
	if _calls == 0 or not connector.is_on():
		_clock.stop()
		return
	var seconds: int = (Time.get_ticks_msec() - _since) / 1000
	_say("Claude is building — %d call%s, %d:%02d" % [_calls,
		"" if _calls == 1 else "s", seconds / 60, seconds % 60], CONNECTED)


func _say(text: String, colour: Color) -> void:
	_status.text = text
	_dot.color = colour
	_state_row.visible = not text.is_empty()


## Which parts of the section are on screen, from the state it is in.
func _show() -> void:
	var on: bool = connector.is_on()
	var has_address: bool = not connector.address().is_empty()
	_intro.visible = not on and not connector.used()
	_in_view.visible = on
	_steps_toggle.visible = on and connector.used()
	_steps_toggle.text = ("Hide how to connect" if _on_box.visible
		else "How to connect Claude again")
	_new_address.visible = has_address


## A tool call as a step on the card: what Claude did, in words, with the
## detail that says which — the part it looked for, the thing it scaled.
static func said(tool: String, arguments: Dictionary = {}) -> String:
	var about: String = ""
	for key: String in ["query", "subject", "name", "part", "path", "from"]:
		if arguments.has(key) and str(arguments[key]).strip_edges() != "":
			about = str(arguments[key]).strip_edges()
			break
	if about.length() > 60:
		about = about.substr(0, 57) + "..."
	var bricks: int = (arguments.get("bricks", []) as Array).size() \
		if arguments.get("bricks") is Array else 0
	match tool:
		"search_parts": return "Looked up parts: “%s”" % about
		"plan_scale":
			return "Worked out the scale for %s, %s m long" % [
				about if not about.is_empty() else "it",
				str(arguments.get("longest_metres", "?"))]
		"find_reference": return "Looked for a picture of %s" % about
		"how_real_sets_build_this": return "Asked how real sets build %s" % about
		"check_design": return "Checked a design of %d bricks" % bricks
		"submit_design":
			return "Built “%s”, %d bricks and its patterns" % [about, bricks] \
				if not about.is_empty() else "Built a design"
		"edit_model": return "Changed the model"
		"look_at_model": return "Read what is built"
		"view_model": return "Looked at the model from %s" % (about if not about.is_empty() else "a new angle")
		"clear_model": return "Cleared the baseplate"
		"save_model": return "Saved the model"
		"show_technique": return "Looked up how to do %s" % about
		"attachment_points": return "Worked out where a part attaches"
	return tool.replace("_", " ").capitalize()


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label
