## Connect your AI: the AI app a person already uses, connected to their
## Brickworks account, building in their tab.
##
## The owner (2026-11-02): connecting ChatGPT, Gemini or any provider should
## be as easy as Claude, and the workflows as alike as each allows. So the
## section is a chooser of every assistant in one table (Assistants,
## assets/assistants.json), Claude first, and Connect does the chosen one's
## way in the fewest steps it allows, its steps beside: Claude's form filled
## in, as below; Cursor's or VS Code's install link; Claude Code's, Codex's
## or Gemini CLI's command copied; or the address copied and ChatGPT's,
## Gemini's, Le Chat's, Perplexity's or Grok's own page opened. The sign-in,
## the tab listening, the line saying who is building and the card in the
## conversation are the same for all of them, each said in the caller's
## name (ClaudeConnector.caller).
##
## The other way in besides an API key. Someone on a Claude plan presses
## Connect Claude: claude.ai opens on "Add custom connector" with Brickworks
## already filled in (claude.ai's own install link), they press Add and
## Connect, sign in to Brickworks and allow it, and Claude is connected —
## to their account, once, for every Brickworks tab they open, on any
## device. An account that has had Claude connected is offered Claude's
## list of connectors beside it, to connect the Brickworks it may have there
## again, since adding it again sets one up anew, its tool permissions to
## choose again. Then they ask Claude to build, and it builds in the tab, where
## they watch it. The same for Claude Code (a command, copied in one click,
## to paste: neither it nor the Claude desktop app documents a link that
## fills a connector in, read 2026-10-31) and the Claude desktop app (which
## shows what was added on claude.ai). Brickworks
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

## Claude connected to this tab (ClaudeConnector, a Later class).
var connector: Node

## Claude's own list of the person's connectors (Customize › Connectors),
## where a Brickworks already there is connected again (ClaudeConnector
## opens it).
const CONNECTORS := "https://claude.ai/customize/connectors"
## Why that list is offered, in one line, beside Connect Claude.
const ALREADY := ("A Brickworks already in your connectors connects again "
	+ "with its own Connect, keeping its tool permissions.")

var _title: Label
var _here: CheckButton
var _intro: Label
## The AI app to connect, from the table (ClaudeConnector.assistant).
var _choice: OptionButton
## Who may, for the chosen one, and what it cannot do yet.
var _plan: Label
var _connect: Button
var _already: VBoxContainer
var _already_link: LinkButton
var _ways: HBoxContainer
var _state_row: HBoxContainer
var _dot: ColorRect
var _status: Label
var _guide: VBoxContainer
var _guide_head: Label
var _step_one: Label
## The chosen one's steps after its first, a line each.
var _step_more: Label
var _come_back: Label
var _fallback: Label
var _signed_as: Label
var _shared: LineEdit
var _copy: Button
var _code_box: VBoxContainer
var _code_said: Label
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
## connected again or the tab is switched on. [member _parted_from] is who.
var _parted: bool = false
var _parted_from: String = ""
var _linked: bool = false

const WAITING := Color(0.95, 0.72, 0.25)
const CONNECTED := Color(0.35, 0.8, 0.45)
const TROUBLE := Color(0.95, 0.4, 0.35)
const OFF := Color(0.55, 0.57, 0.6)
const ASK := "“Build a small red house in Brickworks.”"


func setup(with: Node) -> void:
	connector = with
	add_theme_constant_override("separation", 8)

	add_child(HSeparator.new())
	var head := HBoxContainer.new()
	add_child(head)
	_title = Label.new()
	_title.text = "Or connect your AI"
	_title.add_theme_font_size_override("font_size", 14)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	# Whether Claude may build in this tab. On by itself once Claude is
	# connected to the account; the person can switch this tab off.
	_here = CheckButton.new()
	_here.focus_mode = Control.FOCUS_NONE
	_here.tooltip_text = "Let your AI build in this tab, or stop it"
	_here.toggled.connect(func(on: bool) -> void:
		if on:
			connector.start()
		else:
			connector.stop(true))
	head.add_child(_here)

	_intro = _line("No key needed: connect the AI app you use to your "
		+ "Brickworks account once, then ask it to build. It builds here, on "
		+ "your plan with it.", 11, 0.8)
	add_child(_intro)

	# Which one, Claude first, in the table's order; a line between the
	# chat apps, the terminal's, the editors' and any other.
	var choice_row := HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 8)
	add_child(choice_row)
	var your_ai: Label = _line("Your AI", 12, 0.85)
	your_ai.autowrap_mode = TextServer.AUTOWRAP_OFF
	choice_row.add_child(your_ai)
	_choice = OptionButton.new()
	_choice.add_theme_font_size_override("font_size", 12)
	_choice.accessibility_name = "Your AI"
	_choice.tooltip_text = "The AI app you use: Connect adds Brickworks to it"
	_choice.focus_mode = Control.FOCUS_NONE
	_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice.fit_to_longest_item = false
	var group: String = ""
	for one: Dictionary in Assistants.all():
		if not group.is_empty() and str(one.get("group", "")) != group:
			_choice.add_separator()
		group = str(one.get("group", ""))
		_choice.add_item(str(one["name"]))
		_choice.set_item_metadata(_choice.item_count - 1, str(one["id"]))
	_choice.item_selected.connect(func(at: int) -> void:
		connector.choose(str(_choice.get_item_metadata(at))))
	choice_row.add_child(_choice)
	_plan = _line("", 11, 0.7)
	add_child(_plan)

	_connect = Button.new()
	_connect.text = "Connect Claude"
	_connect.custom_minimum_size = Vector2(0, 34)
	_connect.focus_mode = Control.FOCUS_NONE
	_connect.tooltip_text = "Opens claude.ai with Brickworks filled in"
	_connect.pressed.connect(func() -> void:
		if _claude() and connector.connected():
			connector.open_in_claude()
			return
		_connect_in_claude(false))
	add_child(_connect)

	# An account that has had Claude may have Brickworks in its connectors
	# still: that one connects again keeping its tool permissions, so its
	# list is one click too (ClaudeConnector.had_claude).
	_already = VBoxContainer.new()
	_already.add_theme_constant_override("separation", 2)
	_already.visible = false
	add_child(_already)
	_already_link = Look.link("Already in your Claude? Open your connectors", 11)
	_already_link.tooltip_text = "Opens your connectors in Claude, where Brickworks is"
	_already_link.pressed.connect(func() -> void: _connect_in_claude(true))
	_already.add_child(_already_link)
	_already.add_child(_line(ALREADY, 11, 0.7))

	_ways = HBoxContainer.new()
	_ways.add_theme_constant_override("separation", 12)
	add_child(_ways)
	# One click copies the command and opens what to do with it, under the
	# link: Claude Code has no link that fills a connector in.
	_code_link = Look.link("Claude Code", 11)
	_code_link.tooltip_text = "Copies the command that adds Brickworks to Claude Code"
	_code_link.pressed.connect(func() -> void:
		if not _code_box.visible:
			DisplayServer.clipboard_set(connector.claude_code_command())
		_open_only(_code_box))
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

	# After Connect Claude: what to do in the tab that just opened — the
	# form filled in, or the list, to connect the one there (the words are
	# set in _show).
	_guide = _box()
	_guide_head = _line("", 12, 0.85)
	_guide.add_child(_guide_head)
	_step_one = _line("", 12, 0.85)
	_guide.add_child(_step_one)
	_step_more = _line("", 12, 0.85)
	_guide.add_child(_step_more)
	_signed_as = _line("", 12, 0.85)
	_guide.add_child(_signed_as)
	_come_back = _line("", 12, 0.85)
	_guide.add_child(_come_back)
	_fallback = _line("", 11, 0.7)
	_guide.add_child(_fallback)
	var shared_row := _row()
	_guide.add_child(shared_row)
	_shared = _field(shared_row, "")
	_copy = _copy_button(shared_row, func() -> String: return str(connector.adding()["copy"]))

	_code_box = _box()
	_code_said = _line("Copied. Run it in a terminal, then type /mcp in Claude "
		+ "Code, choose brickworks and Authenticate. Your browser opens here to "
		+ "sign in.", 12, 0.85)
	_code_box.add_child(_code_said)
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
	# Each way opens under the row of their links, where the person just
	# clicked: below Claude's part of the panel, Claude Code's "Copied" was
	# off the foot of a laptop's panel (connect3, 2026-10-31).
	for box: VBoxContainer in [_private_box, _desktop_box, _code_box]:
		move_child(box, _ways.get_index() + 1)

	_copied = _line("Copied.", 11, 0.7)
	_copied.visible = false
	add_child(_copied)

	# The one thing about this way that surprises people, said where they
	# will be when it matters.
	_in_view = _line("Your AI builds in this tab while you talk to it in its "
		+ "own app, and keeps going when it is out of view. Side by side, you "
		+ "can watch it build.", 11, 0.7)
	add_child(_in_view)

	_disconnect = Look.link("Disconnect Claude", 11)
	_disconnect.tooltip_text = ("Every AI app connected to your Brickworks "
		+ "account loses it until you connect it again.")
	_disconnect.pressed.connect(func() -> void:
		if await connector.disconnect_claude() < 0:
			_say("Could not reach Brickworks to disconnect. Try again.", TROUBLE))
	add_child(_disconnect)

	connector.listening.connect(_on_listening)
	connector.called.connect(_on_called)
	connector.connections_changed.connect(func(_now: Array) -> void:
		if connector.connected():
			_parted = false
			_parted_from = _clients()
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
	# Let in while the session kept here is renewed, and then answered.
	if connector.account != null:
		connector.account.changed.connect(_settle)
	connector.assistant_chosen.connect(func(_id: String) -> void:
		_guide.visible = false
		_copied.visible = false
		_settle())
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
		_title.text = "Connect your AI" if only else "Or connect your AI"


func controls_by_name() -> Dictionary:
	var named: Dictionary = _tab_view.controls_by_name() if _tab_view != null else {}
	return named.merged({"connect_claude": _connect, "connect_choice": _choice, "claude_here": _here,
		"connector_shared": _shared, "connector_copy": _copy,
		"connector_already": _already_link,
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


## Connect the chosen assistant, or Claude's list ([param listed]): this
## tab listens, and says what to do where it went.
func _connect_in_claude(listed: bool) -> void:
	if listed:
		connector.connect_claude(true)
	else:
		connector.connect_assistant()
	_guide.visible = true
	_code_box.visible = false
	_desktop_box.visible = false
	_settle()


## Which of the three ways is open, one at a time.
func _open_only(box: VBoxContainer) -> void:
	var opening: bool = not box.visible
	for one: VBoxContainer in [_guide, _code_box, _desktop_box, _private_box]:
		one.visible = opening and one == box
	_settle()
	if opening:
		_into_view(box)


## [param box] scrolled into the panel's view once it is laid out.
func _into_view(box: Control) -> void:
	# Read one frame on, the box just shown was 3,815 px tall, and the panel
	# scrolled 16 px where it fitted: Claude Code went from under the pointer
	# that pressed it, so its tooltip came back (connect_form_probe).
	var up: Node = get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		LaidOut.into_view(up as ScrollContainer, box)


## The state line for where things stand, when nothing newer has said it.
func _settle() -> void:
	var on: bool = connector.is_on()
	var linked: bool = connector.connected()
	var name: String = connector.assistant_name()
	if linked:
		_guide.visible = false
	if on and _calls > 0:
		_tick()
	elif linked and on:
		_say("Connected to %s — %s." % [_clients(), "%s reached this tab at %s" % [connector.caller, _heard]
			if not _heard.is_empty() else "it builds in this tab"], CONNECTED)
	elif linked:
		_say("%s is connected to your account, but switched off in this tab."
			% _clients(), OFF)
	elif _parted and not on:
		_say("Disconnected. %s can no longer reach your Brickworks; connect again any time."
			% (_parted_from if not _parted_from.is_empty() else "Claude"), OFF)
	elif on and connector.account != null and connector.account.renewing:
		_say(Account.waiting_words("%s can reach this tab" % name), WAITING)
	elif connector.waiting_for_claude():
		_say("Waiting for you to connect in %s…" % name, WAITING)
	elif on and not _heard.is_empty():
		_say("Connected — %s reached this tab at %s." % [connector.caller, _heard], CONNECTED)
	elif on and connector.used():
		_say("Connected through this tab's private address.", CONNECTED)
	elif on:
		_say("On. Waiting for %s — press Connect %s." % [name, name], WAITING)
	elif connector.used():
		_say("Off. %s cannot reach this tab." % name, OFF)
	else:
		_say("", OFF)
	_show()


## Your AI reached the tab: a tool by name, or "" for the handshake and
## the tool list, which is it connecting.
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


## How much the caller has done, and for how long, in its name: "ChatGPT
## is building — 3 calls in 0:41". Each step is told in the conversation
## above, on a card like the app's own designs get; the model itself is the
## main report, built on the baseplate as this updates.
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
	_say("%s is building — %d call%s in %d:%02d" % [connector.caller, _calls,
		"" if _calls == 1 else "s", seconds / 60, seconds % 60], CONNECTED)


## Which AI apps are connected, in words: "Claude", "Claude and ChatGPT".
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


## Whether Claude is the one chosen, whose form, list and apps are its own.
func _claude() -> bool:
	return connector.assistant == Assistants.CLAUDE


## What the chosen one's Connect has done, as the guide's first line says
## it: [param way] as Assistants.adding gives it.
static func done_words(way: String, name: String) -> String:
	match way:
		"link":
			return "%s opens with Brickworks filled in, if it is installed. There:" % name
		"command":
			return "The command that adds Brickworks to %s is copied:" % name
		"open":
			return "The address is copied, and %s has opened in a new tab. There:" % name
	return "The address is copied. In your AI app:"


## Which parts of the section are on screen, from the state it is in.
func _show() -> void:
	var on: bool = connector.is_on()
	var linked: bool = connector.connected()
	var claude: bool = _claude()
	var row: Dictionary = Assistants.find(connector.assistant)
	var name: String = connector.assistant_name()
	var way: Dictionary = connector.adding()
	var steps: Array = row.get("steps", []) if row.get("steps") is Array else []
	for n: int in _choice.item_count:
		if str(_choice.get_item_metadata(n)) == connector.assistant and _choice.selected != n:
			_choice.select(n)
	_plan.text = str(row.get("plan", "")) + ("\n" + str(row["limits"])
		if not str(row.get("limits", "")).is_empty() else "")
	_plan.visible = not _plan.text.is_empty()
	var who: String = connector.account.email if connector.account != null else ""
	if claude and connector.last_opened == CONNECTORS:
		_guide_head.text = ("Claude's connectors have opened in a new tab "
			+ "(Customize › Connectors). There:")
		_step_one.text = ("1. Under Your connectors, select Brickworks and press "
			+ "Connect, or Reconnect if it says so.")
		_step_more.text = ""
		_fallback.text = ("Not in your list? Press Connect Claude above, which "
			+ "fills the form in, or paste this there (it is copied):")
	elif claude:
		_guide_head.text = "claude.ai has opened in a new tab with Brickworks filled in. There:"
		_step_one.text = "1. Press Add, then Connect."
		_step_more.text = ""
		_fallback.text = ("No new tab? In Claude, open Customize, Connectors, "
			+ "Add custom connector, and paste this (it is copied):")
	else:
		_guide_head.text = done_words(str(way["way"]), name)
		var lines := PackedStringArray()
		for n: int in steps.size():
			lines.append("%d. %s" % [n + 1, steps[n]])
		_step_one.text = lines[0] if not lines.is_empty() else ""
		_step_more.text = "\n".join(lines.slice(1))
		_fallback.text = {"link": "Nothing opened? Add a remote MCP server named brickworks at "
				+ "this address in %s (it is copied):" % name,
			"command": "The command, to copy again:",
			"open": "No new tab? Open %s yourself and paste this (it is copied):" % name,
		}.get(str(way["way"]), "The address (it is copied):")
	_step_more.visible = not _step_more.text.is_empty()
	var count: int = 1 if claude else maxi(steps.size(), 1)
	_signed_as.text = ("%d. Sign in to Brickworks as %s if asked, and press Allow." % [count + 1, who]
		if not who.is_empty() else "%d. Sign in to Brickworks if asked, and press Allow." % (count + 1))
	_come_back.text = ("%d. Come back: this says Connected. Then ask %s: " % [count + 2, name]) + ASK
	_connect.tooltip_text = ("Opens your connectors in Claude, where Brickworks is"
		if claude and linked else "Opens claude.ai with Brickworks filled in" if claude
		else {"link": "Opens %s with Brickworks filled in" % name,
			"command": "Copies the command that adds Brickworks to %s" % name,
			"open": "Copies the address and opens %s" % name,
		}.get(str(way["way"]), "Copies the address"))
	_already.visible = claude and connector.had_claude and not linked
	_shared.text = str(way["copy"])
	_command.text = connector.claude_code_command()
	for one: Node in _desktop_box.find_children("*", "LineEdit", true, false):
		(one as LineEdit).text = connector.shared_address()
	_intro.visible = not linked and not on and not connector.used()
	var waiting: bool = connector.waiting_for_claude()
	_connect.text = ("Open in Claude" if claude and linked
		else "Connect %s again" % name if waiting else "Connect %s" % name)
	# Claude's own apps, beside Claude: Claude Code's command and the
	# desktop app. The private address is anyone's.
	_code_link.visible = claude
	_desktop_link.visible = claude
	if not claude:
		_code_box.visible = false
		_desktop_box.visible = false
	_here.visible = linked or on or connector.used() or _private_box.visible
	_in_view.visible = on
	_disconnect.visible = linked
	_disconnect.text = "Disconnect %s" % _clients()
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
