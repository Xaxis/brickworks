## Design on your Claude plan: Claude, connected to your Brickworks account.
##
## The other way in besides an API key. Someone on a Claude plan presses
## Connect Claude: claude.ai opens on "Add custom connector" with Brickworks
## already filled in (claude.ai's own install link), they press Add and
## Connect, sign in to Brickworks and allow it, and Claude is connected —
## to their account, once, for every Brickworks tab they open, on any
## device. An account that has had Claude connected is sent instead to
## Claude's list of connectors, to connect the Brickworks it has there
## again, since adding it again sets one up anew, its tool permissions to
## choose again. Then they ask Claude to build, and it builds in the tab, where
## they watch it. The same for Claude Code (a command to paste) and the
## Claude desktop app (which shows what was added on claude.ai). Brickworks
## never sees a Claude login, token or key, and never calls a model: Claude
## is the client, which is ordinary use of Anthropic's own apps.
##
## Until 2026-10-11 each browser had a private address to paste into
## Claude by hand. That still works, folded away under "Private address",
## for everyone who added one.
##
## The brief is typed in Claude, not here — the one thing about this mode
## that has to be said plainly, because everything else in the panel takes
## a brief.
class_name ConnectorForm
extends VBoxContainer

var connector: ClaudeConnector

var _title: Label
var _here: CheckButton
var _intro: Label
var _connect: Button
var _ways: HBoxContainer
var _state_row: HBoxContainer
var _dot: ColorRect
var _status: Label
var _guide: VBoxContainer
var _guide_head: Label
var _step_one: Label
var _fallback: Label
var _signed_as: Label
var _shared: LineEdit
var _copy: Button
var _code_box: VBoxContainer
var _command: LineEdit
var _code_copy: Button
var _desktop_box: VBoxContainer
var _desktop_copy: Button
var _private_box: VBoxContainer
var _address: LineEdit
var _private_copy: Button
var _copied: Label
var _new_address: LinkButton
var _reuse_box: HBoxContainer
var _reuse_field: LineEdit
var _in_view: Label
var _disconnect: LinkButton
var _code_link: LinkButton
var _desktop_link: LinkButton
var _private_link: LinkButton
var _tab_view: ClaudeTabView
## The calls of the chat that called last, and since when (its first call
## here), as the line says them. Counted for each chat: two chats working in
## one tab were added up as one (tabwalk, 2026-10-19). chat -> [calls, since
## in ticks]; "" for calls no chat was named for (the desktop's port).
var _calls: int = 0
var _since: int = 0
var _counts: Dictionary = {}
var _heard: String = ""
## Claude was connected, and has been disconnected since: said until it is
## connected again or the tab is switched on.
var _parted: bool = false
var _linked: bool = false

const WAITING := Color(0.95, 0.72, 0.25)
const CONNECTED := Color(0.35, 0.8, 0.45)
const TROUBLE := Color(0.95, 0.4, 0.35)
const OFF := Color(0.55, 0.57, 0.6)
const ASK := "“Build a small red house in Brickworks.”"


func setup(with: ClaudeConnector) -> void:
	connector = with
	add_theme_constant_override("separation", 8)

	add_child(HSeparator.new())
	var head := HBoxContainer.new()
	add_child(head)
	_title = Label.new()
	_title.text = "Or with your Claude plan"
	_title.add_theme_font_size_override("font_size", 14)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	# Whether Claude may build in this tab. On by itself once Claude is
	# connected to the account; the person can switch this tab off.
	_here = CheckButton.new()
	_here.focus_mode = Control.FOCUS_NONE
	_here.tooltip_text = "Let Claude build in this tab, or stop it"
	_here.toggled.connect(func(on: bool) -> void:
		if on:
			connector.start()
		else:
			connector.stop(true))
	head.add_child(_here)

	_intro = _line("On Claude Pro or Max, no key needed: connect Claude to "
		+ "your Brickworks account once, then ask Claude to build. It builds "
		+ "here, on your plan's usage.", 11, 0.8)
	add_child(_intro)

	_connect = Button.new()
	_connect.text = "Connect Claude"
	_connect.custom_minimum_size = Vector2(0, 34)
	_connect.focus_mode = Control.FOCUS_NONE
	_connect.tooltip_text = "Opens claude.ai with Brickworks filled in"
	_connect.pressed.connect(func() -> void:
		if connector.connected():
			connector.open_in_claude()
			return
		connector.connect_claude()
		_guide.visible = true
		_code_box.visible = false
		_desktop_box.visible = false
		_settle())
	add_child(_connect)

	_ways = HBoxContainer.new()
	_ways.add_theme_constant_override("separation", 12)
	add_child(_ways)
	_code_link = Look.link("Claude Code", 11)
	_code_link.pressed.connect(func() -> void: _open_only(_code_box))
	_ways.add_child(_code_link)
	_desktop_link = Look.link("Claude app", 11)
	_desktop_link.pressed.connect(func() -> void: _open_only(_desktop_box))
	_ways.add_child(_desktop_link)
	_private_link = Look.link("Private address", 11)
	_private_link.pressed.connect(func() -> void: _open_only(_private_box))
	_ways.add_child(_private_link)

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

	# This tab as Claude knows it, the chats working in it, and a new chat
	# for it (ClaudeTabView): shown while Claude can reach this tab.
	_tab_view = ClaudeTabView.new()
	add_child(_tab_view)
	_tab_view.setup(connector)

	# After Connect Claude: what to do in the tab that just opened — adding
	# Brickworks the first time, connecting the one there after that
	# ([member ClaudeConnector.had_claude]; the words are set in _show).
	_guide = _box()
	_guide_head = _line("", 12, 0.85)
	_guide.add_child(_guide_head)
	_step_one = _line("", 12, 0.85)
	_guide.add_child(_step_one)
	_signed_as = _line("", 12, 0.85)
	_guide.add_child(_signed_as)
	_guide.add_child(_line("3. Come back: this says Connected. Then ask Claude: "
		+ ASK, 12, 0.85))
	_fallback = _line("", 11, 0.7)
	_guide.add_child(_fallback)
	var shared_row := _row()
	_guide.add_child(shared_row)
	_shared = _field(shared_row, "")
	_copy = _copy_button(shared_row, func() -> String: return connector.shared_address())

	_code_box = _box()
	_code_box.add_child(_line("Claude Code: run this, then type /mcp in Claude "
		+ "Code, choose brickworks and Authenticate. Your browser opens here to "
		+ "sign in.", 12, 0.85))
	var code_row := _row()
	_code_box.add_child(code_row)
	_command = _field(code_row, "")
	_code_copy = _copy_button(code_row, func() -> String: return connector.claude_code_command())
	_code_box.add_child(_line("Claude Code signed in with the same Claude account "
		+ "as claude.ai has the connector from there too.", 11, 0.7))

	_desktop_box = _box()
	_desktop_box.add_child(_line("The Claude desktop and mobile apps use the "
		+ "connectors on your Claude account: Connect Claude above adds it there "
		+ "too. Or in the app: Customize, Connectors, Add custom connector, name "
		+ "it Brickworks and paste:", 12, 0.85))
	var desktop_row := _row()
	_desktop_box.add_child(desktop_row)
	_field(desktop_row, "")
	_desktop_copy = _copy_button(desktop_row, func() -> String: return connector.shared_address())

	# The way before accounts: this browser's own address, added by hand.
	_private_box = _box()
	_private_box.add_child(_line("This browser's own address, the way before "
		+ "Claude could sign in. Ones already added to Claude keep working. "
		+ "Anyone with it can build in this tab while it is on.", 11, 0.7))
	var private_row := _row()
	_private_box.add_child(private_row)
	_address = _field(private_row, "Switch on to make one")
	_address.tooltip_text = ("Anyone with this address can build in this "
		+ "tab while it is on — keep it to yourself.")
	_private_copy = _copy_button(private_row, func() -> String: return connector.address())
	_new_address = Look.link("Make a new address", 11)
	_new_address.tooltip_text = ("If the address got out. The old one stops "
		+ "working, and you will need to add the new one to Claude instead.")
	_new_address.pressed.connect(func() -> void: connector.forget())
	_private_box.add_child(_new_address)
	_reuse_box = _row()
	_private_box.add_child(_reuse_box)
	_reuse_field = LineEdit.new()
	_reuse_field.placeholder_text = "Added one before? Paste it here"
	_reuse_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reuse_field.text_submitted.connect(func(_t: String) -> void: _adopt())
	_reuse_box.add_child(_reuse_field)
	var use := Button.new()
	use.text = "Use it"
	use.focus_mode = Control.FOCUS_NONE
	use.pressed.connect(_adopt)
	_reuse_box.add_child(use)

	_copied = _line("Copied.", 11, 0.7)
	_copied.visible = false
	add_child(_copied)

	# The one thing about this way that surprises people, said where they
	# will be when it matters.
	_in_view = _line("Claude builds in this tab while you talk to it in "
		+ "Claude, and keeps going when it is out of view. Side by side, you "
		+ "can watch it build.", 11, 0.7)
	add_child(_in_view)

	_disconnect = Look.link("Disconnect Claude", 11)
	_disconnect.tooltip_text = ("Claude can no longer reach your Brickworks "
		+ "account, from any of its apps, until you connect it again.")
	_disconnect.pressed.connect(func() -> void:
		if await connector.disconnect_claude() < 0:
			_say("Could not reach Brickworks to disconnect. Try again.", TROUBLE))
	add_child(_disconnect)

	connector.listening.connect(_on_listening)
	connector.called.connect(_on_called)
	connector.connections_changed.connect(func(_now: Array) -> void:
		if connector.connected():
			_parted = false
		elif _linked:
			# Disconnected, here or anywhere: what Claude did is over.
			_parted = true
			_calls = 0
			_counts.clear()
			_heard = ""
		_linked = connector.connected()
		_settle())
	connector.trouble.connect(func(why: String) -> void:
		_say(why, TROUBLE))
	connector.relay_ok.connect(_settle)
	connector.replaced.connect(func() -> void:
		_say("Another Brickworks tab took this one's place. Switch it on here "
			+ "to take it back.", OFF))
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree() and connector.account != null \
				and connector.account.signed_in():
			connector.refresh_connections())
	_on_listening(connector.is_on(), connector.address())


## Claude can reach this tab, or is connected to the account: the plan is
## the way in use.
func is_on() -> bool:
	return connector != null and (connector.is_on() or connector.connected())


func _adopt() -> void:
	var why: String = connector.adopt(_reuse_field.text)
	if not why.is_empty():
		_say(why, TROUBLE)
		return
	_reuse_field.text = ""


## Titled as the only way on screen, or as the second of two.
func alone(only: bool) -> void:
	if _title != null:
		_title.text = "Designing with your Claude plan" if only else "Or with your Claude plan"


func controls_by_name() -> Dictionary:
	var named: Dictionary = _tab_view.controls_by_name() if _tab_view != null else {}
	return named.merged({"connect_claude": _connect, "claude_here": _here,
		"connector_shared": _shared, "connector_copy": _copy,
		"connector_code": _code_link, "connector_code_copy": _code_copy,
		"connector_desktop": _desktop_link, "connector_desktop_copy": _desktop_copy,
		"connector_private": _private_link, "connector_address": _address,
		"connector_private_copy": _private_copy, "claude_disconnect": _disconnect})


func _on_listening(on: bool, address: String) -> void:
	_here.set_pressed_no_signal(on)
	_address.text = address
	_copied.visible = false
	_calls = 0
	_counts.clear()
	_heard = ""
	_settle()


## Which of the three ways is open, one at a time.
func _open_only(box: VBoxContainer) -> void:
	var opening: bool = not box.visible
	for one: VBoxContainer in [_guide, _code_box, _desktop_box, _private_box]:
		one.visible = opening and one == box
	_settle()


## The state line for where things stand, when nothing newer has said it.
func _settle() -> void:
	var on: bool = connector.is_on()
	var linked: bool = connector.connected()
	if linked:
		_guide.visible = false
	if on and _calls > 0:
		_tick()
	elif linked and on:
		_say("Connected to %s — %s." % [_clients(), "Claude reached this tab at "
			+ _heard if not _heard.is_empty() else "it builds in this tab"], CONNECTED)
	elif linked:
		_say("%s is connected to your account, but switched off in this tab."
			% _clients(), OFF)
	elif _parted and not on:
		_say("Disconnected. Claude can no longer reach your Brickworks; connect "
			+ "again any time.", OFF)
	elif connector.waiting_for_claude():
		_say("Waiting for you to connect in Claude…", WAITING)
	elif on and not _heard.is_empty():
		_say("Connected — Claude reached this tab at %s." % _heard, CONNECTED)
	elif on and connector.used():
		_say("Connected through this tab's private address.", CONNECTED)
	elif on:
		_say("On. Waiting for Claude — press Connect Claude.", WAITING)
	elif connector.used():
		_say("Off. Claude cannot reach this tab.", OFF)
	else:
		_say("", OFF)
	_show()


## Claude reached the tab: a tool by name, or "" for the handshake and
## the tool list, which is Claude connecting.
func _on_called(tool: String, _arguments: Dictionary, chat: String = "") -> void:
	var now: Dictionary = Time.get_time_dict_from_system()
	_heard = "%02d:%02d" % [now.hour, now.minute]
	_guide.visible = false
	if tool.is_empty():
		if _calls == 0:
			_settle()
		return
	var count: Array = _counts.get(chat, [0, Time.get_ticks_msec()])
	count[0] = int(count[0]) + 1
	_counts[chat] = count
	_calls = count[0]
	_since = count[1]
	_tick()
	_show()


## How much Claude has done, and for how long. Each step is told in the
## conversation above, on a card like the app's own designs get; the model
## itself is the main report, built on the baseplate as this updates.
##
## Said as each call comes, from the first call to this one, and not again
## every second: the line ticked on a one-second timer from Claude's first
## call until the tab was switched off, and each tick drew the whole window
## again. In a browser drawing in software that is a frame of 12 to 15
## CPU-seconds, so the page never stopped drawing once Claude had called,
## and a picture Claude asked for waited behind every frame queued
## (2026-10-16, measured: 89 to 185 CPU-seconds of drawing in 20 s standing
## still, against 0.2 before Claude's first call).
func _tick() -> void:
	if _calls == 0 or not connector.is_on():
		return
	var seconds: int = (Time.get_ticks_msec() - _since) / 1000
	_say("Claude is building — %d call%s in %d:%02d" % [_calls,
		"" if _calls == 1 else "s", seconds / 60, seconds % 60], CONNECTED)


## Which of Claude's apps are connected, in words: "Claude", "Claude and
## Claude Code".
func _clients() -> String:
	var names := PackedStringArray()
	for one: Variant in connector.connections:
		var name: String = str((one as Dictionary).get("client", "Claude"))
		if not names.has(name):
			names.append(name)
	if names.is_empty():
		return "Claude"
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


func _say(text: String, colour: Color) -> void:
	_status.text = text
	_dot.color = colour
	_state_row.visible = not text.is_empty()


## Which parts of the section are on screen, from the state it is in.
func _show() -> void:
	var on: bool = connector.is_on()
	var linked: bool = connector.connected()
	var who: String = connector.account.email if connector.account != null else ""
	_signed_as.text = ("2. Sign in to Brickworks as %s if asked, and press Allow." % who
		if not who.is_empty() else "2. Sign in to Brickworks if asked, and press Allow.")
	if connector.had_claude:
		_guide_head.text = ("Claude's connectors have opened in a new tab "
			+ "(Customize › Connectors). There:")
		_step_one.text = ("1. Under Your connectors, select Brickworks and press "
			+ "Connect, or Reconnect if it says so. Connect the one you have rather "
			+ "than adding it again, which sets up a new one with its tool "
			+ "permissions to choose again.")
		_fallback.text = ("In the Claude desktop app: Customize in the sidebar, then "
			+ "Connectors. Not in your list? Add custom connector there, and paste "
			+ "this (it is copied):")
	else:
		_guide_head.text = "claude.ai has opened in a new tab with Brickworks filled in. There:"
		_step_one.text = "1. Press Add, then Connect."
		_fallback.text = ("No new tab? In Claude, open Customize, Connectors, "
			+ "Add custom connector, and paste this (it is copied):")
	_connect.tooltip_text = ("Opens your connectors in Claude, where Brickworks is"
		if connector.had_claude or linked else "Opens claude.ai with Brickworks filled in")
	_shared.text = connector.shared_address()
	_command.text = connector.claude_code_command()
	for one: Node in _desktop_box.find_children("*", "LineEdit", true, false):
		(one as LineEdit).text = connector.shared_address()
	_intro.visible = not linked and not on and not connector.used()
	_connect.text = ("Open in Claude" if linked
		else "Connect Claude again" if connector.waiting_for_claude() else "Connect Claude")
	_here.visible = linked or on or connector.used() or _private_box.visible
	_in_view.visible = on
	_disconnect.visible = linked
	_new_address.visible = not connector.address().is_empty()


func _box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.visible = false
	add_child(box)
	return box


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	return row


func _field(row: HBoxContainer, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.editable = false
	field.placeholder_text = placeholder
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return field


func _copy_button(row: HBoxContainer, what: Callable) -> Button:
	var button := Button.new()
	button.text = "Copy"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		var text: String = what.call()
		if text.is_empty():
			return
		DisplayServer.clipboard_set(text)
		_copied.visible = true)
	row.add_child(button)
	return button


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
				_number(arguments.get("longest_metres", "?"))]
		"find_reference": return "Looked for a picture of %s" % about
		"how_real_sets_build_this": return "Asked how real sets build %s" % about
		"check_design": return "Checked a design of %d bricks" % bricks
		"submit_design":
			if bool(arguments.get("sketch", false)):
				return "Sketched “%s”, %d bricks" % [about, bricks] \
					if not about.is_empty() else "Sketched an idea"
			return "Built “%s”, %d bricks and its patterns" % [about, bricks] \
				if not about.is_empty() else "Built a design"
		"choose_sketch": return "Chose sketch %s" % _number(arguments.get("sketch", "?"))
		"edit_model": return "Changed the model"
		"look_at_model": return "Read what is built"
		"view_model": return "Looked at the model from %s" % (about if not about.is_empty() else "a new angle")
		"clear_model": return "Cleared the baseplate"
		"save_model": return "Saved the model"
		"show_technique": return "Looked up how to do %s" % about
		"read_guide": return "Read the guide on %s" % about
		"find_techniques": return "Looked up how real sets built %s" % about
		"find_parts_like": return "Looked for a part that reads as %s" % about
		"place_technique":
			return "Laid %s as a real set built it" % str(arguments.get("id", "a piece"))
		"attachment_points": return "Worked out where a part attaches"
		"add_minifig": return "Stood %s in the model" % (about if not about.is_empty() else "a figure")
	return tool.replace("_", " ").capitalize()


## 30, not 30.0: JSON has one kind of number and Godot reads it as a float.
static func _number(value: Variant) -> String:
	if value is float and is_equal_approx(value, roundf(value)):
		return str(int(value))
	return str(value)


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label
